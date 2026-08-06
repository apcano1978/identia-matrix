require "application_system_test_case"

class RepositoriesTest < ApplicationSystemTestCase
  setup do
    DesignSeed.call
    sign_in_as Platform::User.find_by!(platform_id: 1)
    visit client_repository_path("vivla", "booking-core")
  end

  test "el repositorio no tiene pipeline ni estado, y lo dice" do
    assert_text "registro · nada que atender"
    assert_text "Un repositorio no tiene pipeline ni estado. El trabajo vive en el evolutivo."
    assert_no_selector "[data-strip]"
  end

  test "lista los evolutivos del mas reciente al mas antiguo" do
    codes = all("a[href*='/initiatives/']").map(&:text)

    assert_equal %w[ev-014 ev-031 ev-009 ev-002], codes
  end

  # El párrafo es el producto entero en una línea: sin él la ficha es una lista
  # de identificadores.
  test "cada entrada dice que se decidio ahi" do
    assert_text "Invalidación incremental por rango en lugar de reconstrucción anual"
    assert_text "pricing-svc pasa a ser la única autoridad de precio"
  end

  test "y los dos sha, que no son el mismo" do
    within("div", text: "Unificar precios y calendario", match: :first) do
      assert_text "base 4f2a9c1"
      assert_text "ejecutado c31d5a8"
    end
  end

  test "un evolutivo sin firma no tiene commit ejecutado" do
    assert_text "aún no"
  end

  test "el ADR en disputa se marca, no se borra" do
    assert_text "ADR-007"
    assert_text "en disputa"
    assert_text "ev-014 disputa ADR-007"
    # Y el que sigue vigente sigue ahí.
    assert_text "ADR-004"
  end

  test "el panel enseña la forma canonica de citar codigo" do
    assert_text "[src:code/booking-core:<fichero>#L<línea>@<sha7>]"
    assert_text "El calificador de repositorio es obligatorio"
  end

  test "un repositorio sin CI lo dice en vez de fingir" do
    assert_text "sin verificación automática"
  end
end
