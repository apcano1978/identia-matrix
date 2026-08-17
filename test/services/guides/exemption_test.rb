# frozen_string_literal: true

require "test_helper"

# El ⊗ irrecorrible · levantar la mano y autorizar.
#
# Hacen falta DOS personas. Un bloqueo perpetuo no protege nada: empuja a que
# alguien marque el paso como recorrido sin haberlo hecho, que es el único
# desenlace peor que no cerrarlo.
class Guides::ExemptionTest < ActiveSupport::TestCase
  setup do
    @client = build_client(slug: "vivla")
    @initiative = place(build_initiative(client: @client, code: "ev-031"), :gate_2)
    @blocked = build_platform_user(role: :admin)
    @approver = build_platform_user(role: :admin)

    dod = build_dod(initiative: @initiative)
    report = build_report(dod: dod)
    @guide = TestGuide.create!(initiative: @initiative, code: "guia-031",
                               verification_report: report)
    @step = GuideStep.create!(
      test_guide: @guide, position: 3, title: "Festivo entre servicios",
      evidence_origin: :sole_evidence,
      dod_criterion: build_criterion(dod: dod, critical: true))
  end

  # ── Levantar la mano ──────────────────────────────────────────────────────

  test "levantar la mano abre una escalada de paso irrecorrible" do
    escalation = raise_hand.escalation

    assert_predicate escalation, :unwalkable_step?
    assert_predicate escalation, :open?
    assert_equal @step, escalation.guide_step
    assert_equal @blocked, escalation.opened_by_user
  end

  # El aviso, sin construir un sistema de notificaciones: la escalada detiene el
  # evolutivo y aparece sola en la bandeja del dashboard.
  test "y detiene el evolutivo, que es lo que lo mete en la bandeja" do
    raise_hand

    assert_predicate @initiative.reload, :status_escalated?
    assert_equal "escalated", Event.order(:id).last.kind
  end

  test "levantar la mano no cierra nada" do
    raise_hand

    assert_not_predicate @step.reload, :settled?
    assert_not_predicate @step, :exempted?
  end

  test "hace falta decir por qué" do
    assert_raises(Guides::RaiseHand::Refused) { raise_hand(reason: "") }
  end

  test "no se levanta la mano dos veces sobre el mismo paso" do
    raise_hand

    assert_raises(Guides::RaiseHand::Refused) { raise_hand }
  end

  test "ni sobre un paso ya recorrido" do
    Guides::WalkStep.call(step: @step, user: @blocked)

    assert_raises(Guides::RaiseHand::Refused) { raise_hand }
  end

  # ── Autorizar ─────────────────────────────────────────────────────────────

  test "autorizar exime el paso y resuelve la escalada" do
    raise_hand
    result = authorize

    assert_predicate result.step, :exempted?
    assert_equal @approver, result.step.exempted_by_user
    assert_predicate result.escalation, :resolved?
    assert_equal @approver, result.escalation.resolved_by_user
  end

  # Eximido NO es recorrido, y se guarda distinto: si contara como recorrido, la
  # cobertura diría «recorridos» sobre pasos que nadie hizo, y LINK no tendría
  # cómo narrar el desvío.
  test "eximido no es recorrido, y la cobertura los distingue" do
    raise_hand
    authorize

    coverage = @guide.reload.coverage

    assert_equal 0, coverage[:walked]
    assert_equal 1, coverage[:exempted]
    assert_nil @step.reload.walked_at
  end

  # La autorización es una decisión humana: entra como nota de nivel ORIGEN,
  # que es lo que LINK citará al narrar el desvío en el cierre.
  test "queda una nota humana de nivel ORIGEN con el motivo" do
    raise_hand
    note = authorize.human_note

    assert_equal @approver, note.author_user
    assert_includes note.body, "sin recorrerlo"
    assert_predicate Citations::Parse.call!(note.citation), :origin?
  end

  test "el evolutivo vuelve a GATE 2, sin subir iteración ni ciclos" do
    iteration = @initiative.iteration
    cycles = @initiative.qa_cycles_consumed
    raise_hand

    authorize

    assert_predicate @initiative.reload, :at_gate_2?
    assert_predicate @initiative, :status_active?
    assert_equal iteration, @initiative.iteration
    assert_equal cycles, @initiative.qa_cycles_consumed
  end

  # ── Las dos personas ──────────────────────────────────────────────────────

  # La regla que de verdad protege, y no depende de ningún papel.
  test "nadie autoriza su propia solicitud" do
    raise_hand

    error = assert_raises(Guides::AuthorizeExemption::Refused) do
      authorize(user: @blocked)
    end

    assert_includes error.message, "su propia solicitud"
    assert_not_predicate @step.reload, :exempted?
  end

  test "y la policy dice lo mismo, sin llegar al servicio" do
    raise_hand

    assert_not GuideStepPolicy.new(@blocked, @step).authorize_exemption?
    assert GuideStepPolicy.new(@approver, @step).authorize_exemption?
  end

  test "sin mano levantada no hay nada que autorizar" do
    assert_raises(Guides::AuthorizeExemption::Refused) { authorize }
    assert_not GuideStepPolicy.new(@approver, @step).authorize_exemption?
  end

  test "autorizar exige dejar por escrito por qué se cierra sin la prueba" do
    raise_hand

    assert_raises(Guides::AuthorizeExemption::Refused) { authorize(reason: "") }
  end

  # Una eximición sin quién la autorizó o sin la escalada que la respalda no se
  # puede guardar: lo impone el modelo desde F2.
  test "una eximición a mano, sin escalada detrás, no se guarda" do
    @step.exempted_at = Time.current
    @step.exempted_by_user = @approver

    assert_not @step.valid?
    assert_includes @step.errors.attribute_names, :escalation
  end

  private
    def raise_hand(user: @blocked, reason: "no hay entorno de integración")
      Guides::RaiseHand.call(step: @step, user: user, reason: reason)
    end

    def authorize(user: @approver, reason: "lo cubre la revisión manual del acta")
      Guides::AuthorizeExemption.call(step: @step, user: user, reason: reason)
    end
end
