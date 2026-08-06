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
    assert_arrived_at root_path, crumb: "status"

    click_on "CLIENTES"
    assert_arrived_at clients_path, crumb: "clients"

    click_on "VIVLA"
    assert_arrived_at client_path("vivla"), crumb: "clients/vivla"

    click_on "Unificar precios y calendario"
    assert_arrived_at client_initiative_path("vivla", "ev-031"),
                      crumb: "clients/vivla/ev-031"

    click_on "booking-core"
    assert_arrived_at client_repository_path("vivla", "booking-core"),
                      crumb: "clients/vivla/repos/booking-core"
  end

  test "y de vuelta" do
    visit client_repository_path("vivla", "booking-core")
    assert_arrived_at client_repository_path("vivla", "booking-core"),
                      crumb: "clients/vivla/repos/booking-core"

    click_on "← vivla"
    assert_arrived_at client_path("vivla"), crumb: "clients/vivla"

    click_on "← clientes"
    assert_arrived_at clients_path, crumb: "clients"

    click_on "identia-matrix"
    assert_arrived_at root_path, crumb: "status"
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
    assert_arrived_at agents_path, crumb: "agents/tank"

    click_on "DASHBOARD"
    assert_arrived_at root_path, crumb: "status"
  end

  private
    # La URL primero, el breadcrumb después. Esperar solo al breadcrumb hacía el
    # test intermitente: `assert_selector` con filtro de texto reintenta, pero da
    # por buena la pantalla anterior si su rótulo coincide un instante. El path
    # cambia de golpe con la navegación y no admite ambigüedad.
    def assert_arrived_at(path, crumb:)
      assert_current_path path
      assert_selector "header span.text-antique-gold", text: crumb, exact_text: true
    end

    def assert_crumb(text)
      assert_selector "header span.text-antique-gold", text: text, exact_text: true
    end

    def sign_out_and_visit(path)
      Session.delete_all
      page.driver.browser.manage.delete_all_cookies
      visit path
    end
end
