# frozen_string_literal: true

require "test_helper"

# Leer un repositorio al registrarlo. Lo que más se prueba aquí es **lo que NO
# hace**: no ancla. Anclar es irreversible y tiene su propio sitio; esto solo
# mira qué hay dentro y anota por qué no pudo, si no pudo.
class Repositories::ProbeTest < ActiveSupport::TestCase
  # La misma doble que usa `index_test`: toda la interfaz son cuatro métodos.
  class Fuente
    def initialize(sha:, files: 100) = (@sha, @files = sha, files)
    def name = "doble"
    def head_sha(_branch = nil) = @sha
    def files_count(_sha) = @files
  end

  setup do
    @client = build_client(slug: "vivla")
    @repo = build_repository(client: @client, name: "booking-core")
  end

  def probar(fuente)
    Repositories::Source.stub(:for, fuente) do
      Repositories::Probe.call(repository: @repo)
    end
  end

  test "anota el commit, el recuento y cuándo se leyó" do
    probar(Fuente.new(sha: "f7b2e04", files: 3412))

    assert_equal "f7b2e04", @repo.reload.head_sha
    assert_equal 3412, @repo.files_count
    assert @repo.last_synced_at.present?
    assert_nil @repo.indexing_error
  end

  # ⚠ LA PROPIEDAD DEL SERVICIO. El anclaje vive en `initiative_repositories` y
  # lo escribe `Repositories::Index`, una sola vez. Si esto lo tocara, un
  # repositorio releído al registrarlo movería el commit de cada evolutivo que ya
  # lo cita — y las citas emitidas pasarían a apuntar a otro sitio.
  test "y NO ancla nada, ni aunque ya haya evolutivos" do
    initiative = build_initiative(client: @client, code: "ev-031")
    link = InitiativeRepository.create!(initiative: initiative, repository: @repo)

    probar(Fuente.new(sha: "f7b2e04"))

    assert_nil link.reload.pinned_sha
    assert_nil link.indexed_at
  end

  # ── Lo que se anota y no se reintenta ─────────────────────────────────────

  test "un repositorio sin origen legible lo deja escrito, y no levanta" do
    probar(nil)

    assert_equal "sin origen legible", @repo.reload.indexing_error
    assert_nil @repo.last_synced_at
  end

  test "y uno cuyo origen no devuelve commit, también" do
    probar(Fuente.new(sha: nil))

    assert_equal "el origen no devolvió commit", @repo.reload.indexing_error
  end

  # ── Lo que sí se reintenta ────────────────────────────────────────────────

  # `Unreachable` sale hacia arriba porque un 502 no dice nada del repositorio:
  # es lo único que tiene sentido volver a intentar. Cuántas veces lo decide el
  # job, no esto.
  test "un origen que no responde levanta Unreachable" do
    rota = Class.new do
      def head_sha(_branch = nil) = raise(Repositories::GithubSource::Error, "502 en GitHub")
    end.new

    assert_raises(Repositories::Unreachable) { probar(rota) }
  end

  # ⚠ Y deja el motivo escrito ANTES de levantar. Si no, un fallo que agote los
  # reintentos no dejaría ni rastro: el job muere y la ficha sigue diciendo «en
  # cola» para siempre.
  test "y aun así anota el motivo, para que no se pierda con el job" do
    rota = Class.new do
      def head_sha(_branch = nil) = raise(Repositories::GithubSource::Error, "502 en GitHub")
    end.new

    assert_raises(Repositories::Unreachable) { probar(rota) }
    assert_match "502 en GitHub", @repo.reload.indexing_error
  end

  # ── Y se cura solo ────────────────────────────────────────────────────────

  test "un motivo viejo se borra al conseguirlo" do
    probar(nil)
    assert @repo.reload.indexing_error.present?

    probar(Fuente.new(sha: "f7b2e04"))

    assert_nil @repo.reload.indexing_error,
               "la ficha seguiría explicando un fallo que ya no existe"
  end
end
