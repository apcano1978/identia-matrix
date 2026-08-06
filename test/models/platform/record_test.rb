require "test_helper"

# INVARIANTE 1 · matrix no modifica ningún origen.
class Platform::RecordTest < ActiveSupport::TestCase
  test "un registro de la proyección es de solo lectura fuera de la ventana de sincronización" do
    client = build_client

    assert_predicate client, :readonly?
    assert_raises(ActiveRecord::ReadOnlyRecord) { client.update!(name: "Otro") }
  end

  test "solo la sincronización escribe, y declara que lo hace" do
    client = build_client

    Platform::Record.writing { client.update!(name: "Nombre nuevo") }

    assert_equal "Nombre nuevo", client.reload.name
    assert_predicate client, :readonly?
  end

  test "la ventana se cierra aunque el bloque reviente" do
    assert_raises(RuntimeError) { Platform::Record.writing { raise "boom" } }

    assert_not Platform::Record.syncing?
  end

  test "ni siquiera la sincronización borra: lo que desaparece se marca" do
    client = build_client

    error = assert_raises(ActiveRecord::ReadOnlyRecord) do
      Platform::Record.writing { client.destroy }
    end
    assert_match "missing_since", error.message

    Platform::Record.writing { client.update!(missing_since: Time.current) }
    assert_predicate client, :missing_in_platform?
  end
end
