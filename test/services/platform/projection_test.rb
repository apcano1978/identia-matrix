require "test_helper"

class Platform::ProjectionTest < ActiveSupport::TestCase
  test "importar escribe las cinco tablas de la proyección" do
    Platform::Projection.import(Platform::FakeSource)

    assert_equal 6, Platform::Client.count
    # Uno, porque los usuarios reflejan la base de platform y hoy tiene uno.
    # Que esto falle el día que platform gane usuarios es la gracia: avisa de
    # que hay que realinear el catálogo, hasta que F8 traiga la sincronización.
    assert_equal 1, Platform::User.count
    assert_equal 10, Platform::Project.count
    assert_equal 1, Platform::Document.count
    assert_equal 2, Platform::Meeting.count
  end

  test "y solo se puede escribir desde ahí" do
    Platform::Projection.import(Platform::FakeSource)

    assert_raises(ActiveRecord::ReadOnlyRecord) do
      Platform::Client.find_by!(slug: "vivla").update!(name: "Otro")
    end
  end

  test "importar dos veces no duplica" do
    Platform::Projection.import(Platform::FakeSource)

    assert_no_difference "Platform::Client.count" do
      Platform::Projection.import(Platform::FakeSource)
    end
  end

  # El slug va dentro de claves de artefacto inmutables y de citas ya emitidas:
  # si la sincronización lo refrescara, una cita dejaría de resolver.
  test "el slug se congela en el primer alta aunque el origen lo cambie" do
    Platform::Projection.import(Platform::FakeSource)
    renamed = Platform::FakeSource.clients.map do |client|
      client[:slug] == "vivla" ? client.merge(slug: "vivla-sa") : client
    end

    Platform::Projection.import(source_serving(clients: renamed))

    assert Platform::Client.exists?(slug: "vivla")
    assert_not Platform::Client.exists?(slug: "vivla-sa")
  end

  test "el nombre sí se refresca" do
    Platform::Projection.import(Platform::FakeSource)
    renamed = Platform::FakeSource.clients.map do |client|
      client[:slug] == "vivla" ? client.merge(name: "VIVLA S.A.") : client
    end

    Platform::Projection.import(source_serving(clients: renamed))

    assert_equal "VIVLA S.A.", Platform::Client.find_by!(slug: "vivla").name
  end

  # INVARIANTE 1 por su lado menos obvio: lo que desaparece del origen NO se
  # borra. Una cita ya emitida tiene que seguir resolviendo dentro de un
  # artefacto que nadie puede reescribir.
  test "lo que deja de venir del origen se marca, no se borra" do
    Platform::Projection.import(Platform::FakeSource)
    vanished = Platform::Client.find_by!(slug: "cirsa")

    report = Platform::Projection.import(without_cirsa)

    # Dos: el cliente y su proyecto. La marca alcanza a todo lo que deje de
    # venir, no solo a lo que se quitó a mano.
    assert_equal 2, report.missing
    assert Platform::Client.exists?(vanished.id)
    assert_predicate vanished.reload, :missing_in_platform?
    assert_equal 1, Platform::Project.missing_in_platform.count
  end

  test "y si vuelve, deja de estar marcado" do
    Platform::Projection.import(without_cirsa)
    Platform::Projection.import(Platform::FakeSource)

    assert_not_predicate Platform::Client.find_by!(slug: "cirsa"), :missing_in_platform?
  end

  # El scope y el predicado tienen que decir lo mismo: si discrepan, una pantalla
  # lista a alguien que al intentar entrar se encuentra la puerta cerrada.
  test "un usuario ausente del origen deja de poder entrar, y de listarse" do
    Platform::Projection.import(Platform::FakeSource)
    user = Platform::User.first

    Platform::Projection.import(source_serving(users: []))

    assert_not user.reload.may_access_matrix?
    assert_not_includes Platform::User.with_access, user
  end

  test "la fuente real no finge funcionar: llega en F8" do
    assert_raises(NotImplementedError) { Platform::HttpSource.clients }
  end

  private
    # Una fuente a medida: delega en la falsa todo lo que no se le sobrescriba.
    # Sin delegar, servir `clients:` implicaría servir cero usuarios y cero
    # documentos, y la importación los marcaría a todos como desaparecidos — que
    # es lo correcto para una fuente vacía, pero no lo que el test quiere probar.
    # Una fuente que deja de servir un cliente tampoco sirve sus proyectos: es lo
    # que haría platform, y la proyección no puede colgar un proyecto de un
    # cliente que no existe — la clave foránea lo impide.
    def without_cirsa
      cirsa = Platform::FakeSource.clients.find { |c| c[:slug] == "cirsa" }

      source_serving(
        clients: Platform::FakeSource.clients - [ cirsa ],
        projects: Platform::FakeSource.projects.reject { |p|
          p[:client_platform_id] == cirsa[:platform_id]
        })
    end

    def source_serving(**overrides)
      Class.new do
        define_method(:initialize) { |values| @values = values }

        %i[clients users projects documents meetings].each do |kind|
          define_method(kind) do
            @values.fetch(kind) { Platform::FakeSource.public_send(kind) }
          end
        end

        def name = "fake"
      end.new(overrides)
    end
end
