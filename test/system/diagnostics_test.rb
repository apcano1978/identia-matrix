require "application_system_test_case"

# El único test de sistema de F1. No prueba la aplicación —todavía no hay
# aplicación— sino que **el runner arranca un navegador en los dos modos**, que
# es lo que la fase promete.
#
# De paso comprueba que la página de diagnóstico no miente: si Postgres
# responde, el glifo tiene que ser el de «responde». Una pantalla de estado que
# pinta verde pase lo que pase es peor que no tenerla.
class DiagnosticsTest < ApplicationSystemTestCase
  test "la pagina de diagnostico se pinta y refleja el estado real" do
    visit root_path

    assert_text "identia-matrix"
    assert_text "COMPROBACIONES"

    # Si el test corre, Postgres está en pie: la fila tiene que decirlo.
    assert_text "Postgres"
    assert_selector ".text-glyph-done", minimum: 1
  end
end
