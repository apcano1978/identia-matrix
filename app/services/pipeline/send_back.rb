# Cualquier salto hacia atrás. Cubre las cinco bifurcaciones de la tabla de F2
# §2.2 con un solo servicio, porque las cinco comparten la misma mecánica y
# repetirla cinco veces habría dejado cinco sitios donde olvidarse de subir
# `iteration`.
#
# Decide DOS cosas que quien lo llama no debería decidir:
#
#   1. Si toca el contador de QA. La respuesta no viene de un parámetro sino de
#      `VerificationReport#consumes_cycle?` — el invariante 7 vive en una línea
#      y todo pasa por ella.
#   2. Si en vez de devolver hay que ESCALAR, porque el tope ya está. Con el
#      contador en 2 no sube a 3: para el pipeline. Y lo mismo con las
#      devoluciones de MORFEO.
class Pipeline::SendBack
  include Pipeline::Transition

  Result = Data.define(:initiative, :outcome, :stage_entry, :escalation) do
    def sent_back? = outcome == :sent_back
    def escalated? = outcome == :escalated
  end

  def self.call(...) = new(...).call

  def initialize(initiative:, to:, actor: Pipeline::SYSTEM_ACTOR,
                 verification_report: nil, human_note: nil, summary: nil)
    @initiative = initiative
    @to = to.to_s
    @actor = actor
    @verification_report = verification_report
    @human_note = human_note
    @summary = summary
  end

  def call
    validate_destination!
    validate_note!

    initiative.with_lock do
      blocked = cap_reached
      next escalate(blocked) if blocked

      from = initiative.current_stage
      close_current_entry(status: :failed)
      bump_counters
      entry = enter(@to, summary: @summary)
      refresh_cache(stage: @to)
      record_event(kind: "sent_back",
                   message: "#{stage_label(from)} → #{stage_label(@to)}",
                   from: from, to: @to, iteration: initiative.iteration,
                   consumed_qa_cycle: consumes_qa_cycle?)

      Result.new(initiative: initiative, outcome: :sent_back,
                 stage_entry: entry, escalation: nil)
    end
  end

  private
    # Solo ✕ consume. Un informe de solo `?` o solo `⊗` devuelve sin gastar
    # ciclo, que es la diferencia entre este sistema y un gestor de tareas.
    def consumes_qa_cycle? = @verification_report&.consumes_cycle? || false

    # `nil` si se puede devolver; el motivo de escalada si no.
    def cap_reached
      return "qa_cycles_exhausted" if consumes_qa_cycle? &&
                                      initiative.qa_cycles_exhausted?
      return "morfeo_returns_exhausted" if morfeo_returns_exhausted?

      nil
    end

    # El contador de MORFEO se DERIVA de las filas, no se almacena: es el número
    # de veces que MORFEO ya devolvió, y las filas ya lo dicen.
    def morfeo_returns_exhausted?
      return false unless initiative.at_morfeo?

      returns = initiative.stage_entries
                          .where(stage: :morfeo, status: :failed).count

      returns >= Pipeline::MAX_MORFEO_RETURNS
    end

    def escalate(reason)
      result = Pipeline::Escalate.call(
        initiative: initiative, reason: reason, actor: actor,
        verification_report: @verification_report)

      Result.new(initiative: initiative, outcome: :escalated,
                 stage_entry: nil, escalation: result.escalation)
    end

    def bump_counters
      attributes = { iteration: initiative.iteration + 1 }
      if consumes_qa_cycle?
        attributes[:qa_cycles_consumed] = initiative.qa_cycles_consumed + 1
      end

      initiative.update!(attributes)
    end

    def validate_destination!
      unless Initiative::STAGES.include?(@to)
        raise Pipeline::InvalidTransition, "etapa desconocida: #{@to}"
      end

      from_position = Initiative::STAGES.index(initiative.current_stage)
      return if Initiative::STAGES.index(@to) < from_position

      raise Pipeline::InvalidTransition,
            "#{@to} no está antes de #{initiative.current_stage}: para " \
            "avanzar está Pipeline::Advance"
    end

    # GATE 1 devuelve a TRINITY con nota, y la nota es obligatoria: sin ella
    # TRINITY volvería a sellar lo mismo sin saber qué corregir.
    def validate_note!
      return unless initiative.at_gate_1?
      return if @human_note.present?

      raise Pipeline::InvalidTransition,
            "devolver desde GATE 1 exige una nota humana"
    end
end
