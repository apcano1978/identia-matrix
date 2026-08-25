require "test_helper"

# Dar de alta un evolutivo. Un evolutivo no es una fila: son tres cosas, y este
# test existe sobre todo para que sigan siendo tres.
class Initiatives::OpenTest < ActiveSupport::TestCase
  include DomainBuilders

  setup do
    @client = build_client(slug: "vivla")
    @repo = build_repository(client: @client, name: "booking-core")
  end

  def abrir(**overrides)
    Initiatives::Open.call(**{ client: @client, title: "Unificar precios",
                               repositories: [ @repo ], actor: "antonio" }.merge(overrides))
  end

  # ── Las tres cosas ─────────────────────────────────────────────────────────

  test "nace con código, repositorios y su entrada de etapa" do
    initiative = abrir

    assert_match(/\Aev-\d{3,}\z/, initiative.code)
    assert_equal [ @repo ], initiative.repositories.to_a
    assert_equal 1, initiative.stage_entries.count
  end

  test "nace en NEED, activo, y ahí espera" do
    initiative = abrir

    assert initiative.at_need?
    assert initiative.status_active?

    entrada = initiative.stage_entries.sole
    assert entrada.at_need?
    assert entrada.active?
    assert_equal 1, entrada.iteration
    assert entrada.entered_at.present?
    assert_nil entrada.exited_at
  end

  test "el caché se DERIVA de la entrada, no se escribe a mano" do
    # El caché solo es defendible mientras se pueda recomputar. Si el alta lo
    # escribiera aparte, empezaría a discrepar del historial sin que nada lo
    # dijera.
    initiative = abrir

    assert_empty StageCache.rebuild(Initiative.where(id: initiative.id)),
                 "reconstruir el caché cambió algo: el alta lo escribió a mano"
  end

  test "deja constancia en el event stream" do
    assert_difference -> { Event.count }, 1 do
      @initiative = abrir
    end

    evento = Event.order(:id).last
    assert_equal "initiative_opened", evento.kind
    assert_equal @initiative, evento.initiative
    assert_equal @client, evento.platform_client
    assert_includes evento.message, "booking-core"
  end

  # ── La frontera de cliente ─────────────────────────────────────────────────

  test "no se puede enlazar el repositorio de otro cliente" do
    # Un formulario manipulado manda el id que quiera. Enlazar material ajeno
    # metería el código de otro cliente en el ámbito de este evolutivo, que es
    # lo que el invariante 10 existe para impedir.
    ajeno = build_repository(client: build_client(slug: "caser"), name: "de-otro")

    error = assert_raises(Initiatives::Open::Refused) do
      abrir(repositories: [ @repo, ajeno ])
    end

    assert_includes error.message, "de-otro"
    assert_equal 0, Initiative.count, "no debería haber quedado nada a medias"
  end

  # ── Lo que se rechaza ──────────────────────────────────────────────────────

  test "sin título no se abre" do
    assert_raises(Initiatives::Open::Refused) { abrir(title: "  ") }
    assert_equal 0, Initiative.count
  end

  test "sin repositorio no se abre" do
    # Un evolutivo es trabajo SOBRE código: sin repositorio no habría nada que
    # citar, y el invariante 4 prohíbe afirmar sobre código sin repositorio.
    assert_raises(Initiatives::Open::Refused) { abrir(repositories: []) }
    assert_equal 0, Initiative.count
  end

  test "un fallo a mitad no deja media alta" do
    # Las tres cosas van en la misma transacción, por la misma razón que
    # `Pipeline::Transition` agrupa las suyas.
    Event.stub(:create!, ->(*) { raise "el bus de eventos se cayó" }) do
      assert_raises(RuntimeError) { abrir }
    end

    assert_equal 0, Initiative.count
    assert_equal 0, InitiativeRepository.count
    assert_equal 0, StageEntry.count
  end

  # ── Multi-repo y proyecto ──────────────────────────────────────────────────

  test "puede tocar varios repositorios" do
    otro = build_repository(client: @client, name: "owner-web")
    initiative = abrir(repositories: [ @repo, otro ])

    assert initiative.multi_repo?
    assert_equal %w[booking-core owner-web], initiative.repositories.order(:name).pluck(:name)
  end

  test "vincular el proyecto de platform es lo que lo hace alcanzable por el enlace profundo" do
    proyecto = Platform::Record.writing do
      Platform::Project.create!(platform_id: next_platform_id, platform_client: @client,
                                platform_project_ref: "proj-2291", name: "Precios")
    end
    initiative = abrir(platform_project: proyecto)

    assert_equal proyecto, initiative.platform_project
  end

  test "y sin proyecto también se abre" do
    assert_nil abrir.platform_project
  end
end
