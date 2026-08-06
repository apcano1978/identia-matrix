require "application_system_test_case"

class InitiativesTest < ApplicationSystemTestCase
  setup do
    DesignSeed.call
    sign_in_as Platform::User.find_by!(platform_id: 1)
  end

  test "los doce nodos se pintan con sus etiquetas fijas" do
    open "ev-031"

    labels = all(".grid-pipeline-node span.block.font-medium").map(&:text)
    assert_equal [ "necesidad", "TANK", "NEO", "SERAPH · DoD", "MORFEO", "TRINITY",
                   "GATE 1 · FIRMA", "CLAUDE CODE", "SERAPH · verificación",
                   "GATE 2 · VALIDACIÓN", "LINK", "publicación" ], labels
  end

  # El arco tiene coordenadas fijas de 44 px por nodo: si un nodo mide otra cosa,
  # apunta a la etapa equivocada y nadie se entera mirando.
  test "cada nodo mide 44 px, que es lo que el arco da por hecho" do
    open "ev-031"

    assert_equal 44, evaluate_script(
      "document.querySelector('.grid-pipeline-node').offsetHeight")
  end

  test "el arco de ciclo QA sale apagado cuando el ciclo se resolvio" do
    open "ev-031"

    assert_selector "svg text", text: "↺ ciclo 2 · resuelto"
  end

  test "y en terracota cuando sigue abierto" do
    open "ev-014"

    assert_selector "svg text", text: "↺ 1/2"
    assert_equal "#C98070", find("svg text")[:fill]
  end

  test "sin ciclos no hay arco" do
    open "ev-027"

    assert_no_selector "svg text"
  end

  test "el banner sale de los veredictos, no de un texto guardado" do
    open "ev-031"

    assert_text "ciclo QA 2/2 · SERAPH dio conforme · c5 y c6 quedan ⊗"
  end

  test "el visor renderiza el markdown del artefacto" do
    open "ev-031"

    assert_selector ".markdown-body h1", text: "Guía de pruebas manuales · ev-031"
    assert_selector ".markdown-body h2", text: "01 · Precio servido por pricing-svc"
  end

  # Las pestañas de la maqueta llevan a pantallas que son F6. Hasta entonces
  # seleccionan qué artefacto enseña el visor.
  test "las pestañas seleccionan artefacto" do
    open "ev-031"
    assert_text "guia-pruebas-031.md"

    click_on "dod"

    assert_text "dod-031.md"
    assert_selector ".markdown-body h1", text: "Definición de terminado"
  end

  test "y las de un evolutivo sin artefactos no navegan" do
    open "ev-014"

    assert_text "sin artefactos todavía"
    assert_selector "span.cursor-not-allowed", text: "dod"
    assert_no_selector "a", text: "dod"
  end

  test "source y diff estan apagados: llegan con el bucket en F5" do
    open "ev-031"

    assert_selector "span.cursor-not-allowed", text: "source"
    assert_selector "span.cursor-not-allowed", text: "diff"
    assert_selector "span", text: "rendered"
  end

  test "REFS esta apagada: la procedencia es F4" do
    open "ev-031"

    assert_selector "span.cursor-not-allowed", text: "REFS"
  end

  test "META y LOG cambian sin recargar" do
    open "ev-031"
    assert_text "REPOSITORIOS ANCLADOS"

    click_on "LOG"

    assert_no_text "REPOSITORIOS ANCLADOS"
    assert_current_path client_initiative_path("vivla", "ev-031")
  end

  test "el nexo con platform es un enlace de salida, no una edicion" do
    open "ev-031"

    assert_text "platform ↗ proj-2291"
    assert_no_selector "main form"
  end

  private
    def open(code)
      visit client_initiative_path("vivla", code)
      assert_text "PIPELINE"
    end
end
