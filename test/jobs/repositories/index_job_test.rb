# frozen_string_literal: true

require "test_helper"

# El job que cierra P23: anclar deja de depender de que alguien se acuerde de
# correr una tarea. Lo que se prueba aquí no es el anclaje —eso es de
# `Repositories::Index`— sino **cuándo se rinde y qué deja escrito al hacerlo**.
class Repositories::IndexJobTest < ActiveJob::TestCase
  class Fuente
    def initialize(sha:, files: 100) = (@sha, @files = sha, files)
    def head_sha(_branch = nil) = @sha
    def files_count(_sha) = @files
  end

  class Rota
    def head_sha(_branch = nil) = raise(Repositories::GithubSource::Error, "502 en GitHub")
  end

  setup do
    @client = build_client(slug: "vivla")
    @repo = build_repository(client: @client, name: "booking-core")
    @initiative = build_initiative(client: @client, code: "ev-031")
    @link = InitiativeRepository.create!(initiative: @initiative, repository: @repo)
  end

  test "ancla lo que le nombran" do
    Repositories::Source.stub(:for, Fuente.new(sha: "f7b2e04", files: 3412)) do
      Repositories::IndexJob.perform_now(@initiative.id)
    end

    assert_equal "f7b2e04", @link.reload.pinned_sha
  end

  test "y descarta el evolutivo que ya no existe" do
    assert_nothing_raised { Repositories::IndexJob.perform_now(-1) }
  end

  test "va en la cola de siempre, no en la del latido" do
    assert_equal "default", Repositories::IndexJob.new.queue_name
  end

  # ── Lo que se reintenta y lo que no ───────────────────────────────────────

  # ⚠ UN 502 SÍ, y el PRIMER intento no se rinde.
  #
  # No se comprueba ni con `assert_raises` —`retry_on` atrapa la excepción— ni
  # con `assert_enqueued_jobs`, que exige el adaptador de pruebas y aquí el de
  # Active Job es el de **Sidekiq**. Se comprueba por el efecto, que es lo que
  # importa: queda el motivo escrito y NO la alerta de haberse rendido.
  test "el primer intento anota el motivo pero no se rinde" do
    assert_no_difference -> { Event.where(kind: "repository_unreachable").count } do
      Repositories::Source.stub(:for, Rota.new) do
        Repositories::IndexJob.perform_now(@initiative.id)
      end
    end

    assert_match "502 en GitHub", @link.reload.indexing_error
    assert_nil @link.pinned_sha
  end

  # Y un `remote_url` que no se parsea NO: dentro de treinta segundos seguirá sin
  # parsearse. Reintentarlo sería tráfico y ruido para llegar al mismo sitio.
  test "pero un repositorio sin origen legible no se reintenta" do
    assert_nothing_raised do
      Repositories::Source.stub(:for, nil) do
        Repositories::IndexJob.perform_now(@initiative.id)
      end
    end

    assert_equal "sin origen legible", @link.reload.indexing_error
  end

  # ⚠ DOS INTENTOS Y PARA, que es lo que se pidió. Lo que se comprueba es que el
  # segundo intento **no encola un tercero** y que deja la alerta.
  test "tras dos intentos se rinde, y lo deja dicho" do
    assert_difference -> { Event.where(kind: "repository_unreachable").count }, 1 do
      Repositories::Source.stub(:for, Rota.new) { ultimo_intento(@initiative.id) }
    end

    alerta = Event.where(kind: "repository_unreachable").last
    assert_match "booking-core", alerta.message
    assert_match "tras dos intentos", alerta.message
    assert_equal @initiative, alerta.initiative
  end

  # El motivo se escribe en cada intento, no solo al rendirse: la pantalla no
  # tiene por qué esperar treinta segundos para contar lo que ya se sabe.
  test "y el motivo estaba escrito desde el primer intento" do
    Repositories::Source.stub(:for, Rota.new) do
      Repositories::IndexJob.perform_now(@initiative.id)
    end

    assert_match "502 en GitHub", @link.reload.indexing_error
    assert_match "502 en GitHub", @repo.reload.indexing_error
  end

  # No alerta de lo que sí quedó anclado: un evolutivo con dos repositorios y uno
  # caído tiene un problema, no dos.
  test "la alerta nombra solo lo que se quedó sin anclar" do
    otro = build_repository(client: @client, name: "owner-web")
    InitiativeRepository.create!(initiative: @initiative, repository: otro)

    fuentes = { "booking-core" => Fuente.new(sha: "f7b2e04"), "owner-web" => Rota.new }
    Repositories::Source.stub(:for, ->(repo) { fuentes.fetch(repo.name) }) do
      ultimo_intento(@initiative.id)
    end

    alertas = Event.where(kind: "repository_unreachable")
    assert_equal 1, alertas.count
    assert_match "owner-web", alertas.sole.message
  end

  private
    # El SEGUNDO intento, provocado a mano.
    #
    # ⚠ No se puede usar `perform_enqueued_jobs`: el adaptador de Active Job en
    # test es el de **Sidekiq**, no el de pruebas, así que los reintentos no se
    # ejecutan en línea —es la misma trampa que ya apareció en F11 · B9 con
    # `assert_no_enqueued_jobs`—. `exception_executions` es el contador que mira
    # `retry_on` para decidir si quedan intentos; ponerlo a uno hace que este
    # `perform_now` sea el último y dispare el bloque.
    def ultimo_intento(*arguments)
      job = described_job.new(*arguments)
      job.exception_executions = { "[Repositories::Unreachable]" => 1 }
      job.perform_now
    end

    def described_job = Repositories::IndexJob
end
