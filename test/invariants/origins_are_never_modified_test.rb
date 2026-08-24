require "test_helper"

# INVARIANTE 1 · Matrix nunca modifica un origen.
#
# No es una regla de estilo: es la razón por la que identia-platform puede
# seguir siendo la fuente de verdad del negocio mientras matrix lee de ella.
class OriginsAreNeverModifiedTest < ActiveSupport::TestCase
  PROJECTED = [ Platform::Client, Platform::User, Platform::Project,
                Platform::Document, Platform::Meeting ].freeze

  test "ninguna de las cinco tablas proyectadas se puede editar desde la aplicación" do
    Platform::Projection.import(Platform::FakeSource)

    PROJECTED.each do |model|
      row = model.first

      assert_predicate row, :readonly?, "#{model} no es de solo lectura"
      assert_raises(ActiveRecord::ReadOnlyRecord, "#{model} se dejó editar") do
        row.update!(updated_at: Time.current)
      end
    end
  end

  test "ni borrar, ni siquiera desde la sincronización" do
    Platform::Projection.import(Platform::FakeSource)

    PROJECTED.each do |model|
      assert_raises(ActiveRecord::ReadOnlyRecord) do
        Platform::Record.writing { model.first.destroy }
      end
    end
  end

  test "lo que desaparece del origen se marca, y sigue resolviendo" do
    Platform::Projection.import(Platform::FakeSource)
    document = Platform::Document.first

    Platform::Record.writing { document.update!(missing_since: Time.current) }

    assert_predicate document, :missing_in_platform?
    assert Platform::Document.exists?(document.id)
    assert_equal 1, Platform::Document.missing_in_platform.count
  end

  test "no hay ninguna ruta ni controlador que escriba en la proyección" do
    offenders = scan_sources("app/controllers/**/*.rb").select do |file|
      File.read(file).match?(/Platform::(Client|User|Project|Document|Meeting)\s*\.\s*(create|update|destroy)/)
    end

    assert_empty offenders
  end
end
