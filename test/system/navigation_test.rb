require "application_system_test_case"

# El recorrido entero de la fase: dashboard → clientes → vivla → ev-031 →
# booking-core, y vuelta por los breadcrumbs.
#
# Es el test que comprueba que las seis pantallas están conectadas. Cada una por
# separado puede estar bien y el conjunto no llevar a ninguna parte.
class NavigationTest < ApplicationSystemTestCase
  setup do
    DesignSeed.call
    sign_in_as Platform::User.find_by!(platform_id: 1)
  end

  test "de ida" do
    assert_crumb "status"

    click_on "CLIENTES"
    assert_crumb "clients"

    click_on "VIVLA"
    assert_crumb "clients/vivla"

    click_on "Unificar precios y calendario"
    assert_crumb "clients/vivla/ev-031"

    click_on "booking-core"
    assert_crumb "clients/vivla/repos/booking-core"
  end

  test "y de vuelta" do
    visit client_repository_path("vivla", "booking-core")
    assert_crumb "clients/vivla/repos/booking-core"

    click_on "← vivla"
    assert_crumb "clients/vivla"

    click_on "← clientes"
    assert_crumb "clients"

    click_on "identia-matrix"
    assert_crumb "status"
  end

  test "la raiz es el dashboard y pide sesion" do
    sign_out_and_visit root_path

    assert_current_path new_session_path
    assert_text "acceso con tu cuenta de identia-platform"
  end

  # La decisión de F3: `/up` se queda escueto y la página de diagnóstico se muda
  # a `/diagnostics`, en local y sin autenticar. Un healthcheck que consulta
  # Redis deja de responder justo el día que hace falta leerlo.
  test "diagnostics sigue en pie sin sesion y up sigue escueto" do
    sign_out_and_visit diagnostics_path
    assert_text "COMPROBACIONES"

    visit rails_health_check_path
    assert_no_text "COMPROBACIONES"
  end

  test "el rail lleva a las tres secciones desde cualquier pantalla" do
    visit client_initiative_path("vivla", "ev-031")

    click_on "AGENTES"
    assert_crumb "agents/tank"

    click_on "DASHBOARD"
    assert_crumb "status"
  end

  private
    def assert_crumb(text)
      assert_selector "header span.text-antique-gold", text: text, exact_text: true
    end

    def sign_out_and_visit(path)
      Session.delete_all
      page.driver.browser.manage.delete_all_cookies
      visit path
    end
end
