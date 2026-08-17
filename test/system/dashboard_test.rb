require "application_system_test_case"

class DashboardTest < ApplicationSystemTestCase
  setup do
    DesignSeed.call
    sign_in_as Platform::User.find_by!(platform_id: 1)
  end

  test "las cinco bandejas se pintan con sus glosas" do
    assert_text "## ESPERAN FIRMA"
    assert_text "gate 1 · autoriza la ejecución"
    assert_text "## ESPERAN VALIDACIÓN"
    assert_text "## ESPERAN APROBACIÓN"
    assert_text "## CICLO QA"
    assert_text "## EN CURSO"
  end

  test "la tira de doce de ev-031 coincide glifo a glifo con la maqueta" do
    assert_equal "● ● ● ● ● ● ● ● ● ▤ ○ ○", strip_for("ev-031")
  end

  test "y la de ev-014 tambien, con su ✕ y su vuelta a NEO" do
    assert_equal "● ● ◆ ● ● ● ● ● ✕ ○ ○ ○", strip_for("ev-014")
  end

  test "el filtro funciona de verdad" do
    filter_by "needs:human"

    assert_text "5 de 8"
    within("#trays") do
      assert_text "ev-041"
      assert_no_text "ev-038"
    end
  end

  test "y se puede limpiar" do
    filter_by "status:gate_1"
    within("#trays") { assert_no_text "ev-038" }

    click_on "limpiar"

    within("#trays") { assert_text "ev-038" }
  end

  test "un filtro sin resultados lo dice en vez de dejar la pantalla en blanco" do
    filter_by "client:inexistente"

    assert_text "Nada que atender con este filtro"
  end

  # La pieza viva: una transición lanzada desde fuera de la petición aparece en
  # el panel sin recargar.
  test "el event stream recibe un evento por Turbo" do
    wait_for_turbo_stream
    assert_no_text "NEO · entra"

    initiative = place(Initiative.find_by!(code: "ev-038"), :tank)
    Pipeline::Advance.call(initiative: initiative, actor: "NEO")

    assert_text "NEO · entra", wait: 5
    assert_text "cirsa/ev-038"
  end

  test "el pie cuenta el consumo del dia" do
    assert_text "cost today"
    assert_text(/runs \d+/)
  end

  # Desde F6 el botón lleva a LA PUERTA que hay que atender, no a la ficha: una
  # decisión se toma delante de lo que se está decidiendo, no desde una lista.
  test "el botón de una fila lleva a lo que hay que atender" do
    within("[data-initiative=\'ev-041\']") { click_on "firmar ↗" }

    assert_current_path client_initiative_gate_1_path("caser", "ev-041")
  end

  test "y las bandejas sin puerta siguen llevando al evolutivo" do
    within("[data-initiative=\'ev-038\']") { click_on "abrir ↗" }

    assert_current_path client_initiative_path("cirsa", "ev-038")
  end

  private
    def filter_by(expression)
      fill_in "q", with: expression
      find_field("q").send_keys(:enter)
    end

    def strip_for(code)
      find("[data-strip='#{code}']").all("span").map(&:text).join(" ")
    end
end
