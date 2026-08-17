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

  # ── F5 · el visor y sus tres modos ────────────────────────────────────────

  # `source` enseña el DOCUMENTO: la cabecera y el cuerpo, que es lo que hay en
  # el bucket. La numeración es real, no la 61 recortada de la maqueta.
  test "source enseña el markdown crudo, numerado y con su cabecera" do
    visit client_initiative_path("vivla", "ev-031", artifact: "spec-031",
                                                     view: "source")

    assert_text "key: artifacts://vivla/ev-031/spec-031/v4.md"
    assert_text "checksum: sha256:"
    assert_selector "td", text: "1", match: :first
    assert_text "# Especificación · ev-031"
  end

  # §7.5 · el diff entre las dos versiones del DoD. Lo que cambió es que se
  # añadió el criterio c0, que es la historia que el seed ya contaba.
  test "el diff entre dod-031 v1 y v2 enseña el criterio que se añadió" do
    visit client_initiative_path("vivla", "ev-031", artifact: "dod-031",
                                                     version: 2, view: "diff")

    assert_text "comparando"
    assert_text "− v1"
    assert_text "+ v2"
    assert_selector "tr", text: "## c0 · Compatibilidad entre servicios"
  end

  test "y se puede saltar entre las versiones de un artefacto" do
    visit client_initiative_path("vivla", "ev-031", artifact: "dod-031",
                                                     version: 2)
    click_on "v1"

    assert_text "artifacts://vivla/ev-031/dod-031/v1.md"
    assert_selector ".markdown-body h2", text: "c1 · Precio resuelto en el motor"
    assert_no_selector ".markdown-body h2", text: "c0 · Compatibilidad entre servicios"
  end

  # Un artefacto de una sola versión no ofrece el modo: no hay contra qué
  # comparar. Mismo tratamiento que las pestañas sin artefacto de F3.
  test "un artefacto de una sola versión no ofrece diff" do
    visit client_initiative_path("vivla", "ev-031", artifact: "spec-031")

    assert_selector "span.cursor-not-allowed", text: "diff"
    assert_no_selector "a", text: "diff"
    assert_selector "a", text: "source"
  end

  # ── F4 · procedencia ──────────────────────────────────────────────────────

  # Las cifras del panel de la maqueta, sobre el seed: la spec se apoya en 9
  # citas de origen y 3 derivadas.
  test "REFS cuenta los dos niveles de procedencia" do
    open_refs "ev-031"

    assert_text "◆ ORIGEN"
    assert_text "↳ DERIVADO"
    assert_selector "[data-pane='refs']", text: /◆ ORIGEN\s*9/
    assert_selector "[data-pane='refs']", text: /↳ DERIVADO\s*3/
  end

  # El bloque que justifica que el calificador de repositorio sea obligatorio.
  # El commit va una vez por repositorio, no por cita.
  test "y agrupa el código por repositorio, con su commit fijado" do
    open_refs "ev-031"
    panel = find("[data-pane='refs']")

    assert panel.has_text?("booking-core"), "falta booking-core"
    assert panel.has_text?("@4f2a9c1 · 4 citas")
    assert panel.has_text?("@e91b330 · 2 citas")
    assert panel.has_text?("@b7c0d21 · 1 cita")
    assert panel.has_text?("rates.ts#L40")
  end

  test "el extracto de origen resalta la frase citada" do
    open_refs "ev-031"

    assert_selector "[data-pane='refs']", text: "[src:doc/acta-precios#p2]"
    assert_selector "[data-pane='refs'] mark",
                    text: "una única autoridad de precio"
  end

  # 3 de 12 es el 25 % justo: el umbral es inclusive y la maqueta avisa ahí.
  test "y avisa cuando el corpus empieza a alimentarse de si mismo" do
    open_refs "ev-031"

    assert_text "3 de 12 citas son derivadas"
  end

  test "un evolutivo sin artefactos no finge tener procedencia" do
    open "ev-014"
    click_on "REFS"

    assert_text "Sin artefacto seleccionado"
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
    # La aserción es sobre PLATFORM, no sobre la aplicación entera: desde F4
    # matrix sí escribe —resolver un conflicto de nivel—, y lo que sigue siendo
    # cierto es que aquí no se edita nada del otro sistema. Lo que la
    # aplicación puede escribir lo fija la lista blanca de
    # test/invariants/matrix_writes_almost_nothing_test.rb.
    assert_no_selector "form[action*='platform']"
    assert_no_selector "main input, main select, main textarea"
  end

  # ── El conflicto de nivel · INVARIANTE 8 ──────────────────────────────────

  test "el conflicto de nivel enfrenta las dos citas y da la razón al origen" do
    open_refs "ev-031", artifact: "pkg-045"
    panel = find("[data-pane='refs']")

    assert panel.has_text?("CONFLICTO DE NIVEL")
    assert panel.has_text?("↳ dod/dod-031#c3")
    assert panel.has_text?("redondeo en cliente")
    assert panel.has_text?("gana el ORIGEN")
  end

  test "y se resuelve a favor del origen, que es la única salida que hay" do
    open_refs "ev-031", artifact: "pkg-045"

    assert_no_text "resolver · gana el derivado"
    click_on "resolver · gana el origen"

    click_on "REFS"
    panel = find("[data-pane='refs']")

    assert panel.has_text?("marcado para revisión")
    assert panel.has_no_button?("resolver · gana el origen")
  end

  private
    def open(code)
      visit client_initiative_path("vivla", code)
      assert_text "PIPELINE"
    end

    # REFS enseña la procedencia del artefacto que el visor tiene abierto. El
    # panel de la maqueta es el de la SPEC, que no es el que se abre por defecto
    # —ese es el último del pipeline—, así que se pide explícitamente.
    def open_refs(code, artifact: "spec-031")
      visit client_initiative_path("vivla", code, artifact: artifact)
      assert_text "PIPELINE"
      click_on "REFS"
      assert_text "TODAS"
    end
end
