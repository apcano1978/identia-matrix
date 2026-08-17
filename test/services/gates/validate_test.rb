# frozen_string_literal: true

require "test_helper"

class Gates::ValidateTest < ActiveSupport::TestCase
  setup do
    @client = build_client(slug: "vivla")
    @initiative = place(build_initiative(client: @client, code: "ev-031"), :gate_2)
    @user = build_platform_user(role: :admin)
    @dod = build_dod(initiative: @initiative)
    @report = build_report(dod: @dod)
    @guide = TestGuide.create!(initiative: @initiative, code: "guia-031",
                               verification_report: @report)
  end

  # ── El bloqueo asimétrico ─────────────────────────────────────────────────

  # Lo que bloquea es un paso de ÚNICA EVIDENCIA sobre un criterio CRÍTICO. Ni
  # los auto-verificados ni los no críticos: exigirlos todos convertiría cada
  # GATE 2 en un trámite de diez casillas, y los trámites se sellan sin leer.
  test "dos pasos de única evidencia críticos sin recorrer bloquean" do
    2.times { step(critical: true, origin: :sole_evidence) }

    error = assert_raises(Gates::Validate::Blocked) { validate }

    assert_includes error.message, "2 pasos"
    assert_equal 0, GateValidation.count
  end

  test "recorrer uno sigue bloqueando; recorrer los dos habilita" do
    first = step(critical: true, origin: :sole_evidence)
    second = step(critical: true, origin: :sole_evidence)

    walk(first)
    assert_raises(Gates::Validate::Blocked) { validate }

    walk(second)
    assert_predicate validate.validation, :decision_validated?
  end

  test "los auto-verificados no bloquean por muchos que queden" do
    3.times { step(critical: true, origin: :auto_verified) }

    assert_predicate validate.validation, :decision_validated?
  end

  test "y los de única evidencia NO críticos tampoco" do
    3.times { step(critical: false, origin: :sole_evidence) }

    assert_predicate validate.validation, :decision_validated?
  end

  # Un paso eximido cuenta como resuelto, aunque no esté recorrido.
  test "un paso eximido desbloquea igual que uno recorrido" do
    blocked = step(critical: true, origin: :sole_evidence)
    assert_raises(Gates::Validate::Blocked) { validate }

    exempt(blocked)

    assert_predicate validate.validation, :decision_validated?
  end

  # ── Validar ───────────────────────────────────────────────────────────────

  test "validar avanza a LINK" do
    assert_predicate validate.initiative, :at_link?
  end

  # El snapshot se congela con lo que la persona tenía delante al decidir.
  # Recalcularlo después diría otra cosa.
  test "la cobertura se congela en el momento de decidir" do
    walked = step(critical: true, origin: :sole_evidence)
    step(critical: false, origin: :auto_verified)
    walk(walked)

    snapshot = validate.validation.coverage_snapshot

    assert_equal 2, snapshot["total"]
    assert_equal 1, snapshot["walked"]
    assert_equal 1, snapshot["pending"]
  end

  # ── Rechazar ──────────────────────────────────────────────────────────────

  # La diferencia entera con un ✕: un rechazo humano no es un fallo de
  # verificación, así que sube la iteración y NO consume ciclo de QA.
  test "rechazar devuelve a NEO, sube iteration y no consume ciclo de QA" do
    iteration = @initiative.iteration
    cycles = @initiative.qa_cycles_consumed

    result = reject("El importe se sigue redondeando en el cliente.")

    assert_predicate result.validation, :decision_rejected?
    assert_predicate result.initiative, :at_neo?
    assert_equal iteration + 1, result.initiative.iteration
    assert_equal cycles, result.initiative.qa_cycles_consumed
  end

  test "rechazar exige decir por qué" do
    assert_raises(ArgumentError) { reject(nil) }
    assert_equal 0, GateValidation.count
  end

  # GATE 2 es reversible y acumula filas: es su diferencia con GATE 1.
  test "se puede rechazar y validar después, y quedan las dos decisiones" do
    reject("No sirve todavía.")
    place(@initiative.reload, :gate_2)

    validate

    assert_equal %w[rejected validated],
                 GateValidation.chronological.map(&:decision)
  end

  private
    def validate = Gates::Validate.call(**common, decision: :validated)

    def reject(note)
      Gates::Validate.call(**common, decision: :rejected, rejection_note: note)
    end

    def common
      { initiative: @initiative.reload, guide: @guide, user: @user }
    end

    def step(critical:, origin:)
      criterion = build_criterion(dod: @dod, critical: critical)

      GuideStep.create!(test_guide: @guide, dod_criterion: criterion,
                        position: @guide.guide_steps.count + 1,
                        title: "Un paso", evidence_origin: origin)
    end

    def walk(step) = Guides::WalkStep.call(step: step, user: @user)

    def exempt(step)
      other = build_platform_user(role: :admin)
      Guides::RaiseHand.call(step: step, user: other, reason: "sin entorno")
      place(@initiative.reload, :gate_2)
      Guides::AuthorizeExemption.call(step: step, user: @user,
                                      reason: "se cierra con la revisión manual")
    end
end
