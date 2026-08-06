require "test_helper"

class Platform::ProjectionTest < ActiveSupport::TestCase
  test "importar escribe las cinco tablas de la proyección" do
    Platform::Projection.import(Platform::FakeSource)

    assert_equal 6, Platform::Client.count
    assert_equal 2, Platform::User.count
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

  test "la fuente real no finge funcionar: llega en F8" do
    assert_raises(NotImplementedError) { Platform::HttpSource.clients }
  end

  private
    def source_serving(clients:)
      Class.new do
        define_method(:clients) { clients }
        def users = []
        def projects = []
        def documents = []
        def meetings = []
        def name = "fake"
      end.new
    end
end
