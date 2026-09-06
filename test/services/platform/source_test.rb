require "test_helper"

# La costura de la proyección. Lo que se prueba aquí es que el interruptor
# elija bien y que las admisiones lleguen resueltas a la fuente real: es el
# único sitio donde eso ocurre, porque `HttpSource` no toca la base de datos.
class Platform::SourceTest < ActiveSupport::TestCase
  test "con `fake` sirve la maqueta" do
    with_env("MATRIX_PLATFORM_SOURCE" => "fake") do
      assert_equal Platform::FakeSource, Platform::Source.current
      assert_not Platform::Source.real?
    end
  end

  test "con `platform` la fuente real lleva las admisiones ya resueltas" do
    ClientAdmission.create!(platform_id: 43, reason: "preparando", admitted_by: "antonio")

    with_env("MATRIX_PLATFORM_SOURCE" => "platform") do
      source = Platform::Source.current

      assert_instance_of Platform::HttpSource, source
      assert_equal Set[43], source.instance_variable_get(:@admitted_ids)
    end
  end

  test "las admisiones se leen en cada pasada, no al arrancar" do
    # Admitir a un cliente tiene que surtir efecto en el siguiente latido sin
    # reiniciar nada.
    with_env("MATRIX_PLATFORM_SOURCE" => "platform") do
      assert_empty Platform::Source.current.instance_variable_get(:@admitted_ids)

      ClientAdmission.create!(platform_id: 44, reason: "preparando", admitted_by: "antonio")

      assert_equal Set[44], Platform::Source.current.instance_variable_get(:@admitted_ids)
    end
  end

  test "un valor desconocido en el interruptor no se traga en silencio" do
    with_env("MATRIX_PLATFORM_SOURCE" => "otra-cosa") do
      assert_raises(ArgumentError) { Platform::Source.current }
    end
  end
end
