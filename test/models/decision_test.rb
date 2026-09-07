require "test_helper"

# El acta, fila a fila. Lo que se prueba aquí no es que guarde: es **el ordinal
# y la ventana de edición**, que son las dos cosas de las que dependen citas ya
# emitidas.
class DecisionTest < ActiveSupport::TestCase
  test "el ancla lleva el estado y el ordinal, en el idioma de la gramática" do
    initiative = build_initiative

    assert_equal "abierta-1", decision(initiative, 1, :open).anchor
    assert_equal "cerrada-2", decision(initiative, 2, :closed).anchor
    assert_equal "descartada-3", decision(initiative, 3, :discarded).anchor
  end

  # El ancla que compone tiene que ser una cita que el parser acepte. Sin esto,
  # `Decision#citation` podría producir algo que la gramática rechaza y nadie se
  # enteraría hasta que un agente lo escribiera dentro de un artefacto inmutable.
  test "y la cita que compone la parsea la gramática de F0" do
    initiative = build_initiative
    cita = decision(initiative, 4, :open).citation("arquitecto-031")

    assert_equal "[src:acta/arquitecto-031#abierta-4]", cita

    valid, invalid = Citations::Parse.scan(cita)

    assert_empty invalid
    assert_equal "acta", valid.sole.kind
    assert_equal "abierta-4", valid.sole.anchor
  end

  test "dos decisiones del mismo evolutivo no comparten ordinal" do
    initiative = build_initiative
    decision(initiative, 1, :open)

    assert_raises(ActiveRecord::RecordInvalid) { decision(initiative, 1, :closed) }
  end

  # El ordinal es de SU evolutivo: dos actas distintas empiezan las dos por 1, y
  # eso no es una colisión porque la cita lleva dentro el código del acta.
  test "pero dos evolutivos distintos usan cada uno sus propios números" do
    primera = decision(build_initiative, 1, :open)
    segunda = decision(build_initiative, 1, :open)

    assert_equal 1, primera.ordinal
    assert_equal 1, segunda.ordinal
  end

  test "una decisión sin pregunta no es nada" do
    initiative = build_initiative
    vacia = initiative.decisions.new(project: initiative.project, ordinal: 1,
                                     question: "  ")

    refute_predicate vacia, :valid?
  end

  # ── LA VENTANA DE EDICIÓN ─────────────────────────────────────────────────

  test "mientras el acta no está publicada, una decisión se corrige" do
    initiative = build_initiative
    abierta = decision(initiative, 1, :open)

    assert abierta.update(answer: "Sobre la tarifa base.", status: :closed)
    assert_predicate abierta.reload, :status_closed?
  end

  # La razón no es que el acta sea inmutable —que lo es—: es que de ella salen la
  # spec y los deltas. Cambiar una decisión después dejaría la spec escrita
  # contra unos requisitos que ya no existen.
  test "publicada el acta, ya no: lo que cambie a partir de ahí es otro delta" do
    initiative = build_initiative
    abierta = decision(initiative, 1, :open)
    publish_artifact(initiative: initiative, kind: :acta)

    error = assert_raises(ActiveRecord::ReadOnlyRecord) do
      abierta.update!(answer: "Tarde.", status: :closed)
    end

    assert_match "es otro delta", error.message
    assert_predicate abierta.reload, :status_open?
  end

  # `SendBack#validate_destination!` admite cualquier etapa anterior, `need`
  # incluida. Volver ahí NO reabre el acta, y está escrito porque es la pregunta
  # que se hace quien lo intente.
  test "y volver a la etapa 1 tampoco la reabre" do
    initiative = build_initiative
    abierta = decision(initiative, 1, :open)
    publish_artifact(initiative: initiative, kind: :acta)
    place(initiative, :need)

    assert_raises(ActiveRecord::ReadOnlyRecord) { abierta.update!(status: :closed) }
  end

  test "el estado es posicional, y estos tres números no se mueven" do
    # Es una columna entera: intercalar un estado cambiaría el significado de las
    # filas ya escritas sin tocarlas.
    assert_equal({ "open" => 0, "closed" => 1, "discarded" => 2 },
                 Decision.statuses)
  end

  private
    def decision(initiative, ordinal, status)
      initiative.decisions.create!(
        project: initiative.project, ordinal: ordinal, status: status,
        question: "¿Pregunta #{ordinal}?",
        answer: status == :open ? nil : "Respuesta #{ordinal}.")
    end
end
