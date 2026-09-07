require "application_system_test_case"

# El acta del ARQUITECTO, en pantalla. Las dos mitades del rediseño: a la
# izquierda las decisiones con sus tres estados, a la derecha la conversación que
# las produce.
#
# Los primeros tests miran el acta YA CERRADA que siembra `DesignSeed` —que es
# el estado en el que se lee— y el bloque de abajo recorre un evolutivo nuevo de
# punta a punta: acta vacía → turno → decisiones → cierre → TANK.
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

  # Cerrada el acta, la conversación no continúa: de ella salen la spec y los
  # deltas, y lo que cambie a partir de aquí es otro delta. La pantalla pasa a
  # ser el registro de lo que se decidió.
  test "con el acta cerrada no hay ni formulario ni botón de cerrar" do
    open_acta

    assert_no_selector "textarea"
    assert_no_button "CERRAR Y PASAR A TANK"
    assert_text "El acta está cerrada"
    assert_text "es otro delta"
  end

  test "el coste del acta se cuenta como el de cualquier otro agente" do
    open_acta

    # Cada turno es un `AgentRun`, así que no hay un contador aparte para la
    # conversación ni una segunda forma de hablar con el brain.
    assert_text(/ARQUITECTO · \d+ sesi(ón|ones) ·/)
  end

  # ══ B9 · LA CONVERSACIÓN ═══════════════════════════════════════════════════
  #
  # El recorrido entero sobre un evolutivo NUEVO: acta vacía → un turno →
  # decisiones → cierre → TANK. Es lo que un evolutivo real vive, y ninguna otra
  # prueba lo recorre de punta a punta.

  test "un evolutivo nuevo entra con el acta vacía, y la pantalla dice qué hacer" do
    open_nueva

    assert_text "Todavía no hay ninguna decisión"
    assert_text "TODAS · 0"
    assert_selector "textarea"
  end

  # La pestaña `acta` es la ÚNICA que se enciende sin artefacto: su pantalla es
  # donde se produce, así que apagarla dejaría la conversación sin puerta.
  test "y se llega por su pestaña aunque no haya artefacto todavía" do
    nueva = open_initiative
    visit project_initiative_path("vivla", nueva.slug)

    click_on "acta"

    assert_current_path project_initiative_acta_path("vivla", nueva.slug)
    assert_text "Todavía no hay ninguna decisión"
  end

  test "un turno deja la nota citable y las decisiones que levantó" do
    open_nueva

    fill_in "message", with: "El precio lo manda pricing-svc."
    click_on "Responder al ARQUITECTO"

    assert_text "Turno registrado"
    assert_equal 3, all("[data-decision]").size
    # La mitad de la persona en el diálogo, con su código citable.
    assert_text "El precio lo manda pricing-svc."
    assert_selector "aside", text: /\d{4}-\d{2}-\d{2}-/
  end

  # LA PROPIEDAD DEL BLOQUE, vista desde la pantalla: al volver de pulsar, las
  # decisiones ya están. Un turno encolado habría devuelto la lista vacía.
  test "y contesta en el acto: al recargar no hay nada esperando" do
    open_nueva
    fill_in "message", with: "Adelante."
    click_on "Responder al ARQUITECTO"

    assert_text "es lo único de matrix que no pasa por una cola"
    assert_no_text "está trabajando"
    assert_selector "[data-decision='1']"
  end

  test "cerrar publica el acta y el evolutivo entra en TANK" do
    nueva = open_initiative
    turn_on(nueva, "Adelante.")

    click_on "CERRAR Y PASAR A TANK"

    assert_current_path project_initiative_path("vivla", nueva.slug)
    assert_text "cerrada"
    assert_text "entra en TANK"
    assert_predicate nueva.reload, :at_tank?
  end

  # La decisión del bloque: se cierra con abiertas, y el aviso lo dice en vez de
  # impedirlo. Ese arrastre es el mecanismo entero.
  test "se cierra con decisiones abiertas, avisando de lo que se arrastra" do
    nueva = open_initiative
    turn_on(nueva, "Adelante.")

    assert_text "Se cierra con 1 decisión abierta"
    click_on "CERRAR Y PASAR A TANK"

    assert_text "sin contestar"
    assert_text "MORFEO las levantará"
  end

  test "y un acta sin ninguna decisión no ofrece cerrarse" do
    open_nueva

    assert_no_button "CERRAR Y PASAR A TANK"
  end

  private
    # Un evolutivo recién abierto: en `need`, sin acta y sin decisiones.
    def open_initiative
      Initiatives::Open.call(
        project: Project.find_by!(slug: "vivla"), title: "Cambio nuevo",
        repositories: [ Repository.find_by!(name: "booking-core") ],
        actor: "test")
    end

    def open_nueva
      nueva = open_initiative
      visit project_initiative_acta_path("vivla", nueva.slug)
      assert_selector "h1", text: "Acta de decisiones"
      nueva
    end

    def turn_on(initiative, message)
      visit project_initiative_acta_path("vivla", initiative.slug)
      fill_in "message", with: message
      click_on "Responder al ARQUITECTO"
      assert_text "Turno registrado"
    end

    def open_acta
      visit project_initiative_acta_path("vivla", "precio-festivos")
      assert_selector "h1", text: "Acta de decisiones"
    end
end
