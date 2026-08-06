require "application_system_test_case"

class ClientsTest < ApplicationSystemTestCase
  setup do
    DesignSeed.call
    sign_in_as Platform::User.find_by!(platform_id: 1)
    click_on "CLIENTES"
  end

  test "las seis tarjetas se pintan con sus evolutivos y repositorios" do
    assert_text "6 clientes"
    assert_text "VIVLA"
    within(card_for("VIVLA")) do
      assert_text "5 evolutivos"
      assert_text "3 repositorios"
    end
    assert_text "↳ el evolutivo es el eje de trabajo; el repositorio, el eje de memoria"
  end

  test "el chip de la tarjeta es el corto, no el largo de la matriz" do
    within(card_for("MANGO")) { assert_text "⊘ escalado" }
    within(card_for("MANGO")) { assert_no_text "inconclusive" }
  end

  # LA COMPROBACIÓN DE LA FASE: la matriz de vivla, celda a celda.
  test "la matriz de vivla da cinco evolutivos y tres repositorios" do
    open_vivla

    assert_text "## EVOLUTIVOS"
    assert_text "eje de trabajo · recorren el pipeline de 12 etapas"
    assert_text "## REPOSITORIOS"
    assert_equal 5, all("a[href*='/initiatives/']").size
    assert_equal %w[booking-core owner-web pricing-svc], matrix_columns
  end

  test "y cada celda tiene el color que le toca" do
    open_vivla

    # ev-031 toca los tres y sigue vivo: tres puntos en oro.
    assert_equal %w[oro oro oro], cells_for("ev-031")
    # ev-014 toca solo booking-core.
    assert_equal %w[oro vacío vacío], cells_for("ev-014")
    # ev-009 tocó dos y ya cerró: verde, no oro.
    assert_equal %w[verde verde vacío], cells_for("ev-009")
  end

  test "el pie cuenta los multi-repo sobre todos, no sobre la pagina" do
    open_vivla

    assert_text "2 de 5 evolutivos tocan más de un repositorio"
  end

  test "la ficha avisa de que no se edita aqui" do
    open_vivla

    assert_text "ficha en solo lectura · se gestiona en identia-platform"
    # El único formulario de la pantalla es el de cerrar sesión, en el rail.
    assert_no_selector "main form"
  end

  # Cero PII: de la persona de contacto viaja el cargo, nunca el nombre.
  test "del contacto solo se enseña el cargo" do
    open_vivla

    assert_text "contacto · cto"
    assert_no_text "marta"
  end

  test "el panel explica el modelo y lista los overrides" do
    open_vivla

    assert_text "son dos ejes que se cruzan, no una jerarquía"
    assert_text "antonio"
    assert_text "neo.model.spec_length"
    assert_text "verbose"
  end

  test "de la matriz se entra al evolutivo y del repositorio a su ficha" do
    open_vivla
    click_on "Motor de disponibilidad"
    assert_current_path client_initiative_path("vivla", "ev-014")

    page.go_back
    click_on "booking-core"
    assert_current_path client_repository_path("vivla", "booking-core")
  end

  private
    def open_vivla
      click_on "VIVLA"
      assert_selector "h1", text: "VIVLA"
    end

    def card_for(name) = find("a", text: name, match: :prefer_exact)

    def matrix_columns = all("[data-matrix-column]").map(&:text)

    def cells_for(code)
      find("a[href$='/#{code}']").all("span.text-center span").map do |cell|
        next "vacío" if cell.text == "·"

        cell[:class].include?("text-glyph-done") ? "verde" : "oro"
      end
    end
end
