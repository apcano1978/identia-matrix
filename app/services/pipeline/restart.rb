# El reinicio de un flujo detenido. Solo lo hace una persona, y solo con una
# nota: reanudar sin decir qué cambió deja al agente repitiendo lo mismo.
#
# **El contador se resetea; el historial no.** `qa_cycles_consumed` vuelve a
# cero y `iteration` sube, pero la escalada se queda en la tabla, resuelta. Un
# evolutivo que se atascó dos veces tiene que poder decirlo un año después.
class Pipeline::Restart
  include Pipeline::Transition

  # A dónde se vuelve según por qué se paró. Está declarado y no a criterio de
  # quien implemente: son motivos distintos y volver al sitio equivocado
  # rehace trabajo que estaba bien.
  DESTINATIONS = {
    # Hay algo que corregir en el desarrollo, y la spec es donde empieza.
    "qa_cycles_exhausted" => %w[neo],
    # Depende de dónde estuviera el bloqueante: lo elige quien reinicia.
    "morfeo_returns_exhausted" => %w[neo seraph_dod],
    # No hay nada que corregir: falló el entorno. Se vuelve a verificar.
    "inconclusive_environment" => %w[seraph_verification]
  }.freeze

  Result = Data.define(:initiative, :stage_entry, :escalation)

  def self.call(...) = new(...).call

  def initialize(initiative:, escalation:, human_note:, resolved_by_user:,
                 to: nil, actor: nil)
    @initiative = initiative
    @escalation = escalation
    @human_note = human_note
    @resolved_by_user = resolved_by_user
    @to = to&.to_s
    @actor = actor || resolved_by_user.to_s
  end

  def call
    destination = resolve_destination

    initiative.with_lock do
      close_current_entry(status: :escalated)
      # El reset y la subida, juntos: son la misma decisión.
      initiative.update!(iteration: initiative.iteration + 1,
                         qa_cycles_consumed: 0)
      entry = enter(destination)
      refresh_cache(stage: destination)
      @escalation.update!(resolved_at: Time.current,
                          resolved_by_user: @resolved_by_user,
                          human_note: @human_note)
      record_event(kind: "restarted",
                   message: "REINICIO → #{stage_label(destination)}",
                   reason: @escalation.reason, to: destination,
                   iteration: initiative.iteration,
                   note: @human_note.code)

      Result.new(initiative: initiative, stage_entry: entry,
                 escalation: @escalation)
    end
  end

  private
    def resolve_destination
      allowed = DESTINATIONS[@escalation.reason]

      if allowed.blank?
        raise Pipeline::InvalidTransition,
              "#{@escalation.reason} no detiene el pipeline: se cierra " \
              "autorizando el paso, no reiniciando"
      end

      return allowed.first if allowed.one?

      unless allowed.include?(@to)
        raise Pipeline::InvalidTransition,
              "un reinicio por #{@escalation.reason} tiene que elegir entre " \
              "#{allowed.join(' o ')}"
      end

      @to
    end
end
