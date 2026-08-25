require "test_helper"

# Anclar e indexar. Lo que más se prueba aquí es **que el commit fijado no se
# mueva**: moverlo convertiría en mentira cada cita ya emitida contra él, dentro
# de artefactos que nadie puede reescribir.
class Repositories::IndexTest < ActiveSupport::TestCase
  include DomainBuilders

  # Una fuente cualquiera. Toda la interfaz son cuatro métodos, y por eso hay
  # una de GitHub y una falsa sin que el resto del sistema note la diferencia.
  class Fuente
    attr_reader :peticiones

    def initialize(sha:, files: 100) = (@sha, @files, @peticiones = sha, files, [])
    def name = "doble"
    def head_sha(_branch = nil) = @sha
    def files_count(sha) = @peticiones.push(sha) && @files
  end

  setup do
    @client = build_client(slug: "vivla")
    @repo = build_repository(client: @client, name: "booking-core")
    @initiative = build_initiative(client: @client, code: "ev-031")
    @link = InitiativeRepository.create!(initiative: @initiative, repository: @repo)
  end

  def indexar(fuente)
    Repositories::Source.stub(:for, fuente) do
      Repositories::Index.call(initiative: @initiative)
    end
  end

  # ── El anclaje ─────────────────────────────────────────────────────────────

  test "la primera indexación fija el commit y cuenta" do
    resultado = indexar(Fuente.new(sha: "f7b2e04", files: 3412)).sole

    assert_equal "f7b2e04", @link.reload.pinned_sha
    assert_equal 3412, @link.indexed_files_count
    assert @link.indexed_at.present?
    assert_nil resultado.skipped
  end

  test "el commit fijado NO se mueve aunque el repositorio avance" do
    # Es la propiedad entera. La spec habla de un estado concreto del código y
    # lo dice; si el anclaje siguiera al repositorio, cada cita emitida contra
    # él pasaría a apuntar a otro sitio.
    indexar(Fuente.new(sha: "f7b2e04"))
    indexar(Fuente.new(sha: "aaaaaaa"))

    assert_equal "f7b2e04", @link.reload.pinned_sha,
                 "el anclaje siguió al repositorio: las citas ya emitidas mienten"
  end

  test "pero el head del repositorio SÍ avanza" do
    # Son dos preguntas distintas —«con qué se trabajó» y «dónde está ahora»— y
    # por eso son dos columnas.
    indexar(Fuente.new(sha: "f7b2e04"))
    indexar(Fuente.new(sha: "aaaaaaa"))

    assert_equal "aaaaaaa", @repo.reload.head_sha
    assert_equal "f7b2e04", @link.reload.pinned_sha
  end

  test "se cuenta CONTRA el commit anclado, no contra el nuevo" do
    indexar(Fuente.new(sha: "f7b2e04"))
    fuente = Fuente.new(sha: "aaaaaaa")
    indexar(fuente)

    assert_equal [ "f7b2e04" ], fuente.peticiones,
                 "contó los ficheros de un commit distinto del que se citará"
  end

  # ── Degradación honesta ────────────────────────────────────────────────────

  test "un repositorio sin origen legible se salta, y lo dice" do
    resultado = indexar(nil).sole

    assert_equal "sin origen legible", resultado.skipped
    assert_nil @link.reload.pinned_sha
  end

  test "un repositorio que no responde no tumba la indexación de los demás" do
    otro = build_repository(client: @client, name: "owner-web")
    InitiativeRepository.create!(initiative: @initiative, repository: otro)

    rota = Class.new do
      def head_sha(_branch = nil) = raise(Repositories::GithubSource::Error, "502 en GitHub")
    end.new
    buena = Fuente.new(sha: "6ba4c17")

    fuentes = { "booking-core" => rota, "owner-web" => buena }
    resultados = Repositories::Source.stub(:for, ->(repo) { fuentes.fetch(repo.name) }) do
      Repositories::Index.call(initiative: @initiative)
    end

    assert_equal 1, resultados.count(&:skipped)
    assert_equal "6ba4c17", otro.reload.head_sha, "el que sí respondía se indexó igual"
  end

  test "un origen que no devuelve commit se salta en vez de anclar a nulo" do
    resultado = indexar(Fuente.new(sha: nil)).sole

    assert_equal "el origen no devolvió commit", resultado.skipped
    assert_nil @link.reload.pinned_sha
  end

  # ── Constancia ─────────────────────────────────────────────────────────────

  test "deja constancia con lo indexado y lo que no" do
    otro = build_repository(client: @client, name: "owner-web")
    InitiativeRepository.create!(initiative: @initiative, repository: otro)

    fuentes = { "booking-core" => Fuente.new(sha: "f7b2e04", files: 3412), "owner-web" => nil }
    assert_difference -> { Event.count }, 1 do
      Repositories::Source.stub(:for, ->(repo) { fuentes.fetch(repo.name) }) do
        Repositories::Index.call(initiative: @initiative)
      end
    end

    evento = Event.order(:id).last
    assert_equal "repositories_indexed", evento.kind
    assert_includes evento.message, "3412 ficheros"
    assert_includes evento.message, "1 de 2 repositorios"
  end
end
