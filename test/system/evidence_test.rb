require "application_system_test_case"

# La cadena de evidencia: DoD → informe → guía. Las tres pantallas de lectura
# de F6, sobre el seed.
class EvidenceTest < ApplicationSystemTestCase
  setup do
    DesignSeed.call
    sign_in_as Platform::User.find_by!(platform_id: 1)
  end

  # ── El DoD · el contrato ──────────────────────────────────────────────────

  test "el DoD enseña los once criterios con su traza y su veredicto" do
    open_dod

    assert_text "Definición de terminado"
    assert_selector ".grid-dod-criteria", count: 12 # 11 criterios + la cabecera
    assert_text "pricing-svc es la única autoridad de precio."
  end

  # c0 no es un criterio más: es el de compatibilidad durante la ventana de
  # despliegue, y aparece solo en todo evolutivo que toque más de un repositorio.
  test "y c0 lleva su etiqueta de obligatorio multi-repo" do
    open_dod

    row = find(".grid-dod-criteria", text: "OBLIGATORIO · MULTI-REPO")

    assert row.has_text?("c0")
    assert row.has_text?("entre servicios"), "c0 no responde de un repositorio"
    assert_selector "span", text: "OBLIGATORIO · MULTI-REPO", count: 1,
                            exact_text: true
  end

  # Un criterio sin repositorio es un criterio ENTRE SERVICIOS, y es el que
  # acaba en ⊗.
  test "los criterios sin repositorio se marcan como entre servicios" do
    open_dod

    assert_text "entre servicios"
    assert_text "no soportado aún"
  end

  # Los cuatro contadores, siempre los cuatro: un cero también dice algo —que
  # nada falló— y esconderlo lo convertiría en una ausencia.
  test "los cuatro contadores salen aunque dos estén a cero" do
    open_dod

    tally = find("[data-tally]")

    # `normalize_ws` porque el glifo y su cifra van en dos elementos: sin él,
    # Capybara compara contra el salto de línea que los separa.
    assert tally.has_text?("✓ 9", normalize_ws: true), "9 cumplidos"
    assert tally.has_text?("✕ 0", normalize_ws: true), "ningún incumplido, y se ve el cero"
    assert tally.has_text?("? 0", normalize_ws: true), "ningún no concluyente, y se ve el cero"
    assert tally.has_text?("⊗ 2", normalize_ws: true), "2 no soportados"
  end

  test "y la caja explica por qué hay ⊗" do
    open_dod

    assert_text "exigen integración entre servicios"
    assert_text "ningún CI levanta dos servicios a la vez"
  end

  test "el panel cuenta los criterios por repositorio" do
    open_dod

    assert_text "CRITERIOS POR REPOSITORIO"
    assert_text "MORFEO · SOBRE LA SECUENCIA"
    assert_text "v1 no traía"
  end

  # ── El informe · los cuatro veredictos ────────────────────────────────────

  test "el informe enseña las tres ejecuciones de CI con su commit ejecutado" do
    open_verification

    assert_text "EJECUCIONES DE CI"
    # Los EJECUTADOS, que no son los sellados en GATE 1 (4f2a9c1, e91b330,
    # b7c0d21). Colapsarlos perdería la única forma de saber sobre qué se firmó
    # y sobre qué se verificó.
    assert_text "@c31d5a8"
    assert_text "@2d77b90"
    assert_text "@a04e6c2"
    assert_no_text "@4f2a9c1"
  end

  test "y dice que SERAPH no valida" do
    open_verification

    assert_text "CONFORME · pasa a GATE 2"
    assert_text "SERAPH no valida"
    assert_text "La conformidad final la firma un humano"
  end

  # Los cuatro con su rótulo, en igualdad visual: no son «dos buenos y dos
  # malos», son cuatro resultados distintos.
  test "el informe rotula los cuatro veredictos, incluidos los que están a cero" do
    open_verification

    assert_text "cumplidos"
    assert_text "incumplidos"
    assert_text "no concluyentes"
    assert_text "no soportado aún"
  end

  # Un ⊗ no lleva evidencia sino redirección: es lo que convierte un criterio
  # sin verificar en un paso con dueño.
  test "un ⊗ redirige al paso de la guía que lo cubre" do
    open_verification

    assert_selector "a", text: "guia-pruebas-031 · paso 03"
    assert_selector "a", text: "guia-pruebas-031 · paso 04"
  end

  # ── La guía · un documento, dos lecturas ──────────────────────────────────

  test "la guía conmuta entre sus dos modos sin recargar" do
    open_guide
    assert_text "Lectura continua"

    click_on "validación"

    assert_text "Checklist ejecutable"
    assert_no_text "Lectura continua"
    assert_current_path client_initiative_guide_path("vivla", "ev-031")
  end

  # La asimetría visual es la misma que la regla de bloqueo: un paso de única
  # evidencia es lo único que nadie más ha comprobado.
  test "los pasos de única evidencia gritan y los auto-verificados no" do
    open_guide

    assert_selector "span", exact_text: "ÚNICA EVIDENCIA", count: 2
    assert_selector "span", exact_text: "auto-verificado", count: 2
  end

  test "y cada paso de única evidencia dice qué criterio depende solo de él" do
    open_guide

    assert_text "única prueba de"
    assert_text "SERAPH no puede verificarlo"
  end

  test "la cobertura distingue recorrido, eximido y pendiente" do
    open_guide

    assert_text "COBERTURA DE EVIDENCIA"
    assert_text "2 de 4 pasos son única evidencia"
    assert_text "recorrido"
    assert_text "eximido"
    assert_text "pendiente"
  end

  # ── Marcar un paso ────────────────────────────────────────────────────────

  test "marcar un paso persiste y se refleja en la cobertura" do
    open_guide
    click_on "validación"

    within "#paso-03" do
      click_on "○ marcar recorrido"
    end

    click_on "validación"
    assert_text "recorrido por"
    assert_selector "#paso-03", text: "✓ recorrido"
  end

  # ── Se llega desde la ficha ───────────────────────────────────────────────

  test "las tres pestañas del evolutivo llevan a sus pantallas" do
    visit client_initiative_path("vivla", "ev-031")

    click_on "dod"
    assert_text "Definición de terminado"

    visit client_initiative_path("vivla", "ev-031")
    click_on "verify"
    assert_text "Informe de verificación"

    visit client_initiative_path("vivla", "ev-031")
    click_on "guide"
    assert_text "Guía de pruebas"
  end

  private
    def open_dod
      visit client_initiative_definition_of_done_path("vivla", "ev-031")
      assert_text "CRITERIOS"
    end

    def open_verification
      visit client_initiative_verification_path("vivla", "ev-031")
      assert_text "VEREDICTOS"
    end

    def open_guide
      visit client_initiative_guide_path("vivla", "ev-031")
      assert_text "Guía de pruebas"
    end
end
