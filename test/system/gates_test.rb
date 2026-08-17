require "application_system_test_case"

# Las dos puertas. Aquí se concentra casi todo lo que distingue a este producto
# de un gestor de tareas.
class GatesTest < ApplicationSystemTestCase
  setup do
    DesignSeed.call
    @user = Platform::User.find_by!(platform_id: 1)
    sign_in_as @user
  end

  # ── GATE 1 · el registro de una firma ya dada ─────────────────────────────

  # ev-031 está firmado desde el seed, así que enseña el segundo estado.
  test "GATE 1 firmado enseña el registro, no la acción" do
    open_gate_1 "vivla", "ev-031"

    assert_text "REGISTRO DE FIRMA"
    assert_text "Firmado. La ejecución quedó autorizada."
    assert_text "COMMITS QUE SELLÓ ESTA FIRMA"
    assert_no_selector "input[type=password]"
  end

  # Se firma sobre el commit contra el que se trabajó, no sobre el ejecutado.
  test "y los commits sellados son los anclados, no los ejecutados" do
    open_gate_1 "vivla", "ev-031"

    assert_text "4f2a9c1"
    assert_text "e91b330"
    assert_text "b7c0d21"
    assert_no_text "c31d5a8"
  end

  test "la secuencia de despliegue solo sale en multi-repo, con su ventana" do
    open_gate_1 "vivla", "ev-031"

    assert_text "SECUENCIA DE DESPLIEGUE"
    assert_text "Primero el proveedor de precio"
    assert_text "lo cubre el criterio c0 del DoD"
  end

  # La identidad se congela: el registro sigue diciendo quién firmó aunque esa
  # persona cambie de cargo o desaparezca de platform.
  test "el registro conserva la identidad y la frase que se firmó" do
    open_gate_1 "vivla", "ev-031"

    assert_text "Firmé la entrega de PKG-045"
    assert_text @user.identity_snapshot
    assert_text "Una firma no se modifica ni se borra"
  end

  # ── GATE 1 · firmar de verdad ─────────────────────────────────────────────

  test "un evolutivo sin firmar enseña la parada obligatoria" do
    open_gate_1 "caser", "ev-041"

    assert_text "PARADA OBLIGATORIA"
    assert_text "Nada se ejecuta sin tu firma."
    assert_text "COMMITS QUE SELLA ESTA FIRMA"
    assert_text "TU CRITERIO"
  end

  test "firmar exige la contraseña, y una incorrecta no sella nada" do
    open_gate_1 "caser", "ev-041"

    fill_in "password", with: "la que no es"
    click_on "firmar y liberar"

    assert_text "No se ha firmado"
    assert_text "contraseña"
    assert_equal 1, GateSignature.count, "solo la del seed, la de ev-031"
  end

  test "firmar con la contraseña correcta sella y avanza" do
    open_gate_1 "caser", "ev-041"

    fill_in "password", with: Auth::FakeSource::DEFAULT_PASSWORD
    click_on "firmar y liberar"

    assert_text "GATE 1 firmado"
    assert_text "REGISTRO DE FIRMA"
    assert_predicate Initiative.find_by!(code: "ev-041"), :at_claude_code?
  end

  # La cuarta bifurcación: devuelve a TRINITY y no a NEO, porque lo que está mal
  # es el paquete y no la especificación.
  test "devolver a TRINITY vuelve al paquete, sube iteración y no toca el QA" do
    initiative = Initiative.find_by!(code: "ev-041")
    iteration = initiative.iteration
    cycles = initiative.qa_cycles_consumed
    open_gate_1 "caser", "ev-041"

    fill_in "note", with: "El orden de despliegue invierte los dos primeros."
    click_on "↺ devolver a TRINITY"

    assert_text "Devuelto a TRINITY"
    initiative.reload
    assert_predicate initiative, :at_trinity?
    assert_equal iteration + 1, initiative.iteration
    assert_equal cycles, initiative.qa_cycles_consumed
  end

  test "y exige decir qué corregir" do
    open_gate_1 "caser", "ev-041"

    assert_selector "input[name=note][required]"
  end

  # ── GATE 2 · el bloqueo asimétrico ────────────────────────────────────────

  test "GATE 2 dice qué depende solo de tu recorrido" do
    open_gate_2

    assert_text "Confirmas que lo ejecutado sirve."
    assert_text "No autorizas nada"
    assert_text "2 de 4 pasos son única evidencia"
    assert_text "Criterios del DoD que dependen solo de tu recorrido"
  end

  # Dos pasos de única evidencia críticos sin recorrer: no se puede validar.
  test "con pasos críticos sin recorrer no se puede validar" do
    open_gate_2

    assert_text "No se puede validar todavía"
    assert_no_button "validar y pasar a LINK"
  end

  test "recorrer uno sigue bloqueando; recorrer los dos habilita" do
    open_gate_2
    walk "03"

    assert_text "No se puede validar todavía"

    walk "04"

    assert_text "Todo lo que bloquea está resuelto"
    assert_button "validar y pasar a LINK"
  end

  test "validar pasa a LINK y deja la cobertura congelada" do
    open_gate_2
    walk "03"
    walk "04"
    click_on "validar y pasar a LINK"

    assert_text "GATE 2 validado"
    assert_predicate Initiative.find_by!(code: "ev-031"), :at_link?
    assert_equal({ "total" => 4, "walked" => 4, "exempted" => 0, "pending" => 0 },
                 GateValidation.sole.coverage_snapshot)
  end

  # La diferencia entera con un ✕: un rechazo humano no es un fallo de
  # verificación.
  test "rechazar devuelve a NEO, sube iteración y no consume ciclo de QA" do
    initiative = Initiative.find_by!(code: "ev-031")
    iteration = initiative.iteration
    cycles = initiative.qa_cycles_consumed
    open_gate_2

    fill_in "rejection_note", with: "El importe se sigue redondeando en el cliente."
    click_on "↺ rechazar · devolver a NEO"

    assert_text "Rechazado y devuelto a NEO"
    initiative.reload
    assert_predicate initiative, :at_neo?
    assert_equal iteration + 1, initiative.iteration
    assert_equal cycles, initiative.qa_cycles_consumed
  end

  # ── GATE 2 · el ⊗ irrecorrible ────────────────────────────────────────────

  test "levantar la mano deja el paso esperando a otra persona" do
    open_gate_2

    within "#paso-03" do
      fill_in "reason", with: "no hay entorno de integración"
      click_on "no puedo recorrerlo"
    end

    assert_text "Mano levantada"
    assert_text "no puede recorrerlo"
    assert_predicate Escalation.find_by!(reason: :unwalkable_step), :open?
  end

  # La regla que de verdad protege, y no depende de ningún papel.
  test "y quien la levantó no puede autorizarla" do
    open_gate_2
    within "#paso-03" do
      fill_in "reason", with: "no hay entorno"
      click_on "no puedo recorrerlo"
    end

    assert_text "Lo tiene que autorizar otra persona"
    assert_no_selector "input[value='⊘ autorizar sin recorrer']"
  end

  # Los pasos que no bloquean no ofrecen levantar la mano: no hay nada
  # bloqueado que desbloquear.
  test "un paso auto-verificado no ofrece levantar la mano" do
    open_gate_2

    within "#paso-01" do
      assert_no_selector "input[value='no puedo recorrerlo']"
    end
  end

  test "la caja explica por qué puede cerrarse con ⊗" do
    open_gate_2

    assert_text "Es una decisión registrada, no una omisión"
  end

  # ── Se llega desde el dashboard ───────────────────────────────────────────

  # Solo ev-031 tiene guía sembrada: los demás que esperan validación llevan a
  # su ficha con el aviso de que no hay nada que validar todavía.
  test "el botón de la bandeja lleva a la puerta que hay que atender" do
    visit root_path

    within("[data-initiative='ev-031']") { click_on "validar ↗" }

    assert_text "Confirmas que lo ejecutado sirve."
  end

  test "y el de firmar lleva a GATE 1" do
    visit root_path

    within("[data-initiative='ev-041']") { click_on "firmar ↗" }

    assert_text "Nada se ejecuta sin tu firma."
  end

  private
    def open_gate_1(client, code)
      visit client_initiative_gate_1_path(client, code)
      assert_text "GATE 1"
    end

    def open_gate_2
      visit client_initiative_gate_2_path("vivla", "ev-031")
      assert_text "PASOS"
    end

    # `click_on` no espera a la navegación: sin esperar al acuse, el clic
    # siguiente cae sobre la página vieja. Es la trampa de Capybara que este
    # repo ya tiene documentada tres veces.
    def walk(position)
      within("##{'paso-' + position}") { click_on "○ marcar recorrido" }
      assert_text "Paso #{position} recorrido."
    end
end
