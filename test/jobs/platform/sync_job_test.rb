require "test_helper"

# El latido corre desatendido cada quince minutos: si se rompe, no hay nadie
# mirando. Los dos fallos que este test caza son justo los que no se ven —una
# llamada mal escrita y un latido que sincroniza el seed contra sí mismo.
class Platform::SyncJobTest < ActiveJob::TestCase
  include DomainBuilders

  def con_fuente_real
    previo = ENV["MATRIX_PLATFORM_SOURCE"]
    ENV["MATRIX_PLATFORM_SOURCE"] = "platform"
    yield
  ensure
    ENV["MATRIX_PLATFORM_SOURCE"] = previo
  end

  test "con la fuente falsa no hace nada" do
    # Sincronizar el seed contra sí mismo no aporta nada y llenaría el event
    # stream de ruido en desarrollo.
    build_client

    assert_no_difference -> { Event.count } do
      Platform::SyncJob.perform_now
    end
  end

  test "sin cliente sincroniza el catálogo y luego cada uno" do
    llamados = []
    con_fuente_real do
      Platform::Sync.stub(:discover, -> { llamados << :discover; vacio }) do
        Platform::Sync.stub(:call, ->(client) { llamados << client.slug; vacio(client) }) do
          build_client(slug: "vivla")
          build_client(slug: "caser")
          Platform::SyncJob.perform_now
        end
      end
    end

    assert_equal :discover, llamados.first,
                 "un cliente nuevo tiene que existir antes de pedirle sus fuentes"
    assert_equal %w[caser vivla], llamados.drop(1).sort
  end

  test "con un cliente sincroniza solo ese" do
    # La llamada es posicional. Escribirla con `client:` pasaba un Hash y
    # reventaba en el primer latido de producción, no en desarrollo.
    client = build_client(slug: "vivla")
    recibidos = []

    con_fuente_real do
      Platform::Sync.stub(:call, ->(c) { recibidos << c; vacio(c) }) do
        Platform::SyncJob.perform_now(client.id)
      end
    end

    assert_equal [ client ], recibidos
  end

  private

  def vacio(client = nil)
    Platform::Sync::Result.new(
      client: client,
      report: Platform::Projection::Report.new(created: 0, updated: 0, missing: 0),
      closed_sessions: 0)
  end
end
