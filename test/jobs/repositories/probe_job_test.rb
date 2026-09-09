# frozen_string_literal: true

require "test_helper"

# Leer un repositorio recién registrado. Mismo contrato que el de indexar —dos
# intentos y para, con la alerta escrita— sobre la otra mitad del problema: aquí
# no hay evolutivo todavía, solo un repositorio del que no se sabe nada.
class Repositories::ProbeJobTest < ActiveJob::TestCase
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
  end

  test "lee el repositorio que le nombran" do
    Repositories::Source.stub(:for, Fuente.new(sha: "f7b2e04", files: 3412)) do
      Repositories::ProbeJob.perform_now(@repo.id)
    end

    assert_equal 3412, @repo.reload.files_count
    assert @repo.last_synced_at.present?
  end

  test "y descarta el repositorio que ya no existe" do
    assert_nothing_raised { Repositories::ProbeJob.perform_now(-1) }
  end

  test "va en la cola de siempre, no en la del latido" do
    assert_equal "default", Repositories::ProbeJob.new.queue_name
  end

  test "tras dos intentos se rinde, y lo deja dicho" do
    assert_difference -> { Event.where(kind: "repository_unreachable").count }, 1 do
      Repositories::Source.stub(:for, Rota.new) { ultimo_intento(@repo.id) }
    end

    alerta = Event.where(kind: "repository_unreachable").last
    assert_match "booking-core", alerta.message
    # Sin evolutivo: esto pasa al registrarlo, cuando todavía no hay ninguno.
    assert_nil alerta.initiative_id
    assert_equal @repo.project_id, alerta.project_id
  end

  # Ni siquiera al «último» intento: no hay nada que agotar, porque no se
  # reintenta. El motivo queda escrito y ahí se acaba.
  test "un repositorio sin origen legible no se reintenta, y lo dice" do
    assert_no_difference -> { Event.where(kind: "repository_unreachable").count } do
      Repositories::Source.stub(:for, nil) { Repositories::ProbeJob.perform_now(@repo.id) }
    end

    assert_equal "sin origen legible", @repo.reload.indexing_error
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

    def described_job = Repositories::ProbeJob
end
