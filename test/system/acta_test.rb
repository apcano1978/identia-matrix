require "application_system_test_case"

# El acta del ARQUITECTO, en pantalla. Es la mitad izquierda del rediseño: la
# lista de decisiones con sus tres estados. La conversación —la mitad derecha—
# llega en B9.
class ActaTest < ApplicationSystemTestCase
  setup do
    DesignSeed.call
    sign_in_as Platform::User.find_by!(platform_id: 1)
  end

  test "las once decisiones se pintan, y el titular cuenta decidido contra pendiente" do
    open_acta

    assert_selector "h1", text: "Acta de decisiones"
    # Nueve decididas —cerradas y descartadas— y dos sin contestar. Las
    # descartadas suman con las cerradas porque también están decididas.
    assert_text "9 cerradas · 2 abiertas"
    assert_equal 11, all("[data-decision]").size
  end

  test "cada estado lleva su glifo, y descartada no se pinta como cerrada" do
    open_acta

    assert_selector "[data-decision='1']", text: "● cerrada"
    assert_selector "[data-decision='3']", text: "● descartada"
    assert_selector "[data-decision='4']", text: "◆ abierta"

    # Mismo glifo —las dos están decididas— y distinto tono: lo que se decidió
    # de una descartada es que queda fuera, y pintarla en verde haría parecer
    # que el trabajo la cubre.
    assert_selector "[data-decision='1'] .text-glyph-done"
    assert_selector "[data-decision='3'] .text-terminal-fg-4"
  end

  test "una decisión cerrada enseña su respuesta y la cita que la respalda" do
    open_acta
    fila = find("[data-decision='1']")

    assert fila.has_text?("¿Quién decide el precio cuando calendario y reserva discrepan?")
    assert fila.has_text?("Una única autoridad de precio: pricing-svc")
    assert fila.has_text?("[src:meet/2026-05-02@22:40]")
  end

  # Sin fuente no es un descuido: una decisión abierta todavía no tiene nada que
  # citar, y decirlo distingue «no hay» de «se olvidó».
  test "y una abierta dice que no tiene respuesta ni fuente todavía" do
    open_acta
    fila = find("[data-decision='4']")

    assert fila.has_text?("Sin respuesta.")
    assert fila.has_text?("sin fuente todavía")
  end

  # El ordinal es la identidad de la decisión: es lo que lleva dentro el ancla de
  # la cita, y lo que un agente devuelve para decir cuál cierra.
  test "cada fila compone la cita que la nombra dentro del acta publicada" do
    open_acta

    assert_selector "[data-decision='4']", text: "[src:acta/arquitecto-031#abierta-4]"
    assert_selector "[data-decision='1']", text: "[src:acta/arquitecto-031#cerrada-1]"
  end

  # ── Las tres pestañas ──────────────────────────────────────────────────────

  test "las pestañas filtran, y se pueden enlazar" do
    open_acta

    click_on "ABIERTAS · 2"

    assert_current_path project_initiative_acta_path("vivla", "precio-festivos",
                                                     tab: "abiertas")
    assert_equal 2, all("[data-decision]").size
    assert_selector "[data-decision='4']"
    assert_no_selector "[data-decision='1']"
  end

  test "y CERRADAS lleva también las descartadas, que también están decididas" do
    visit project_initiative_acta_path("vivla", "precio-festivos", tab: "cerradas")

    assert_equal 9, all("[data-decision]").size
    assert_selector "[data-decision='3']", text: "descartada"
  end

  test "una pestaña inventada cae en TODAS" do
    visit project_initiative_acta_path("vivla", "precio-festivos", tab: "inventada")

    assert_equal 11, all("[data-decision]").size
  end

  # ── El arrastre, que es la mitad de por qué el acta existe ────────────────

  test "el aviso dice que lo abierto no bloquea pero se arrastra" do
    open_acta

    assert_text "no bloquean el avance"
    assert_text "MORFEO las levanta como advertencia"
  end

  # ── Cómo se llega, y qué NO se puede hacer ────────────────────────────────

  test "se entra por la cuarta pestaña de evidencia del evolutivo" do
    visit project_initiative_path("vivla", "precio-festivos")
    assert_text "PIPELINE"

    click_on "acta"

    assert_current_path project_initiative_acta_path("vivla", "precio-festivos")
    assert_selector "h1", text: "Acta de decisiones"
  end

  # Un evolutivo abierto antes de F11 no tiene acta y nunca la tendrá: llevar a
  # una pantalla vacía sería peor que decirlo. Mismo tratamiento que las otras
  # tres pestañas de evidencia.
  test "y un evolutivo sin acta la tiene apagada, como las otras tres" do
    visit project_initiative_path("vivla", "motor-disponibilidad")

    assert_selector "span.cursor-not-allowed", text: "acta"
    assert_no_selector "a", text: "acta"
  end

  test "el rail se queda en PROYECTOS, que es donde está el trabajo" do
    open_acta

    assert_selector ".rail-entry-on", text: "PROYECTOS"
  end

  # B8 no añade ninguna escritura: esta pantalla se lee y nada más. La
  # conversación —contestar al ARQUITECTO— es B9, y la pantalla lo dice en vez de
  # enseñar un botón apagado.
  test "es una pantalla de lectura, y dice que contestar llega después" do
    open_acta

    assert_no_selector "main form"
    assert_no_selector "main input, main select, main textarea"
    assert_text "Contestar al ARQUITECTO todavía no se puede desde aquí"
  end

  test "el coste del acta se cuenta como el de cualquier otro agente" do
    open_acta

    # Cada turno es un `AgentRun`, así que no hay un contador aparte para la
    # conversación ni una segunda forma de hablar con el brain.
    assert_text(/ARQUITECTO · \d+ sesi(ón|ones) ·/)
  end

  private
    def open_acta
      visit project_initiative_acta_path("vivla", "precio-festivos")
      assert_selector "h1", text: "Acta de decisiones"
    end
end
