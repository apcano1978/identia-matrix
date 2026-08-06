require "application_system_test_case"

# La página de diagnóstico no miente: si Postgres responde, el glifo tiene que
# ser el de «responde». Una pantalla de estado que pinta verde pase lo que pase
# es peor que no tenerla.
#
# Desde F3 vive en `/diagnostics`: la raíz es el dashboard. Sigue sin autenticar
# y sigue montada solo en local.
class DiagnosticsTest < ApplicationSystemTestCase
  test "la pagina de diagnostico se pinta sin autenticar y refleja el estado real" do
    visit diagnostics_path

    assert_text "identia-matrix"
    assert_text "COMPROBACIONES"

    # Si el test corre, Postgres está en pie: la fila tiene que decirlo.
    assert_text "Postgres"
    assert_selector ".text-glyph-done", minimum: 1
  end
end
