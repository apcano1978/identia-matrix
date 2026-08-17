# frozen_string_literal: true

require "test_helper"

# GATE 1 · la escritura más seria del sistema: irreversible, nominal y autoriza
# a escribir sobre repositorios de un cliente.
class Gates::SignTest < ActiveSupport::TestCase
  setup do
    @client = build_client(slug: "vivla")
    @initiative = place(build_initiative(client: @client, code: "ev-041"), :gate_1)
    @user = build_platform_user(role: :admin)
    @repositories = %w[pricing-svc booking-core].map.with_index do |name, index|
      repository = build_repository(client: @client, name: name,
                                    head_sha: "aaaa00#{index}")
      InitiativeRepository.create!(initiative: @initiative, repository: repository,
                                   pinned_sha: "beef00#{index}")
      repository
    end
    @package = seal_package
  end

  test "firmar sella una fila por repositorio, en orden de despliegue" do
    signature = sign.signature

    assert_equal 2, signature.gate_signature_commits.count
    assert_equal %w[pricing-svc booking-core],
                 signature.commits_in_deploy_order.map { |c| c.repository.name }
    assert signature.covers_package?
  end

  # Se firma sobre el commit contra el que se TRABAJÓ, no sobre la cabeza del
  # repositorio, que puede haber avanzado mientras tanto.
  test "el commit sellado es el anclado en el evolutivo, no la cabeza" do
    commits = sign.signature.commits_in_deploy_order

    assert_equal %w[beef000 beef001], commits.map(&:base_sha)
  end

  # La identidad se congela: si mañana esta persona cambia de cargo o desaparece
  # de platform, el registro sigue diciendo quién firmó.
  test "la identidad del firmante queda congelada" do
    signature = sign.signature

    assert_equal @user.identity_snapshot, signature.identity
    assert_equal @user, signature.signed_by_user
  end

  # La frase la compone el sistema: lo que se firma es una afirmación concreta,
  # no un «acepto» genérico.
  test "la frase de la firma nombra el paquete y los repositorios" do
    statement = sign.signature.statement

    assert_includes statement, "PKG-041"
    assert_includes statement, "2 repositorios"
    assert_includes statement, "asumí la ventana de despliegue"
  end

  test "y en mono-repo no habla de ventana de convivencia" do
    solo = place(build_initiative(client: @client, code: "ev-042"), :gate_1)
    repository = build_repository(client: @client, name: "docs-site")
    InitiativeRepository.create!(initiative: solo, repository: repository,
                                 pinned_sha: "cafe000")
    seal_package(initiative: solo, repositories: [ repository ])

    statement = sign(initiative: solo).signature.statement

    assert_includes statement, "un repositorio"
    assert_not_includes statement, "ventana"
  end

  test "firmar avanza a CLAUDE CODE" do
    assert_predicate sign.initiative, :at_claude_code?
  end

  # ── Lo que no se puede hacer ──────────────────────────────────────────────

  test "firmar exige la contraseña, y una incorrecta no sella nada" do
    error = assert_raises(Gates::Sign::Refused) { sign(password: "la que no es") }

    assert_includes error.message, "contraseña"
    assert_equal 0, GateSignature.count
    assert_predicate @initiative.reload, :at_gate_1?
  end

  test "un paquete ya firmado no se firma dos veces" do
    sign

    assert_raises(Gates::Sign::Refused) { sign }
    assert_equal 1, GateSignature.count
  end

  # Firmar sin saber en qué orden se despliega es autorizar una ventana de
  # convivencia a ciegas.
  #
  # `deploy_order` es NOT NULL en la tabla, así que una fila nunca puede tenerlo
  # a medias: el único modo de que falte la secuencia es que no haya filas. La
  # protección de verdad está en el esquema, y esto comprueba el último hueco
  # que le queda.
  test "un paquete sin secuencia de despliegue no se puede firmar" do
    @package.work_package_repositories.destroy_all

    error = assert_raises(Gates::Sign::Refused) { sign }

    assert_includes error.message, "secuencia de despliegue"
  end

  test "sin paquete sellado no hay nada que firmar" do
    @package.destroy

    assert_raises(Gates::Sign::Refused) { sign }
  end

  # INVARIANTE 9 · la firma no se toca. Lo protege el modelo desde F2; aquí solo
  # se comprueba que sigue siendo cierto sobre lo que produce este servicio.
  test "una firma no se modifica ni se borra" do
    signature = sign.signature

    assert_raises(ActiveRecord::ReadOnlyRecord) { signature.update!(identity: "otro") }
    assert_raises(ActiveRecord::ReadOnlyRecord) { signature.destroy }
  end

  private
    def sign(initiative: @initiative, password: Auth::FakeSource::DEFAULT_PASSWORD)
      Gates::Sign.call(initiative: initiative, user: @user, password: password)
    end

    def seal_package(initiative: @initiative, repositories: @repositories)
      package = WorkPackage.create!(
        initiative: initiative,
        code: "pkg-#{format('%03d', initiative.number)}",
        sealed_at: 1.day.ago, content_hash: "sha256:#{SecureRandom.hex(8)}")

      repositories.each_with_index do |repository, index|
        WorkPackageRepository.create!(
          work_package: package, repository: repository,
          deploy_order: index + 1, write_scope: "src/#{repository.name}")
      end

      package
    end
end
