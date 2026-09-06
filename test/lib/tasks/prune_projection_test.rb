require "test_helper"
require "rake"

# `matrix:prune_projection` es la única puerta por la que se borran filas de la
# proyección, así que sus guardas son lo que se prueba: la que impide vaciarla
# cuando platform contesta con una lista vacía, y la que distingue «esto nunca
# debió entrar» de «esto es historia».
class PruneProjectionTest < ActiveSupport::TestCase
  include DomainBuilders

  # Las tareas se cargan UNA vez POR PROCESO —`RakeHelpers`—, y no por clase: la
  # segunda carga no solo repite avisos de constante, encadena las acciones y
  # hace que el cuerpo de cada tarea se ejecute dos veces. Lo que sí hay que
  # hacer por test es `reenable`, o rake se salta la segunda invocación por
  # considerarla ya cumplida.
  def setup
    load_rake_tasks_once
    Rake::Task["matrix:prune_projection"].reenable
    ENV["MATRIX_PLATFORM_SOURCE"] = "platform"
    ENV.delete("CONFIRM")
  end

  def teardown
    ENV.delete("MATRIX_PLATFORM_SOURCE")
    ENV.delete("CONFIRM")
  end

  # La tarea aborta con `abort`, que es un SystemExit con el mensaje en stderr.
  def podar(vivos:, confirm: false)
    ENV["CONFIRM"] = "1" if confirm
    fuente = Struct.new(:filas) do
      def clients = filas
    end.new(vivos.map { |id| { platform_id: id } })

    salida = nil
    error = nil
    Platform::HttpSource.stub(:new, fuente) do
      salida = capture_io { Rake::Task["matrix:prune_projection"].invoke }.first
    rescue SystemExit => e
      error = e.message
    end
    [ salida, error ]
  end

  test "no poda cuando la fuente devuelve una lista vacía" do
    # Un platform caído y un token mal puesto devuelven listas vacías, no
    # errores. Sin esta guarda, cualquiera de los dos vacía la proyección.
    build_client
    _, error = podar(vivos: [], confirm: true)

    assert_match(/no devolvió ninguno/, error.to_s)
    assert_equal 1, Platform::Client.count
  end

  test "sin CONFIRM enseña lo que sobra y no borra nada" do
    vivo = build_client
    build_client

    salida, = podar(vivos: [ vivo.platform_id ])

    assert_match(/Sobran 1/, salida)
    assert_equal 2, Platform::Client.count, "el ensayo no borra"
  end

  test "con CONFIRM borra el cliente que la fuente ya no reconoce, y sus fuentes" do
    vivo = build_client
    sobra = build_client
    build_meeting(client: sobra)
    build_document(client: sobra)

    podar(vivos: [ vivo.platform_id ], confirm: true)

    assert_equal [ vivo.platform_id ], Platform::Client.pluck(:platform_id)
    assert_equal 0, Platform::Meeting.count
    assert_equal 0, Platform::Document.count
  end

  test "se niega si de un cliente sobrante cuelga trabajo de matrix" do
    # La frontera del sistema: lo que nunca debió entrar se poda; lo que tiene
    # historia se marca ausente. No se deja al criterio de quien la ejecuta.
    vivo = build_client
    sobra = build_client
    build_initiative(client: sobra)

    _, error = podar(vivos: [ vivo.platform_id ], confirm: true)

    assert_match(/cuelga trabajo de matrix/, error.to_s)
    assert_match(/evolutivos/, error.to_s)
    assert_equal 2, Platform::Client.count, "no se borró nada"
  end
end
