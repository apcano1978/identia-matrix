# La mecánica que comparten las cuatro transiciones.
#
# Cada una hace TRES cosas, siempre las tres y siempre en la misma transacción:
# escribe un `stage_entry`, escribe un `event` y actualiza el caché del
# evolutivo. Repartirlas por los servicios dejaría que una se olvidara en uno de
# ellos, y el síntoma sería una tira de glifos que no cuadra con el historial.
module Pipeline::Transition
  extend ActiveSupport::Concern

  private
    attr_reader :initiative, :actor

    # La fila de la etapa en la que el evolutivo está ahora. Se crea si falta:
    # la fila de la etapa en la que estás tiene que existir, y crearla tarde es
    # mejor que no tenerla.
    def current_entry
      initiative.stage_entries.find_or_create_by!(
        stage: initiative.current_stage, iteration: initiative.iteration
      ) do |entry|
        entry.status = initiative.current_stage_status
        entry.qa_cycle = initiative.qa_cycles_consumed
        entry.entered_at = initiative.stage_changed_at || initiative.opened_at
      end
    end

    def close_current_entry(status:)
      current_entry.update!(status: status, exited_at: Time.current)
    end

    # Un retorno INSERTA con la iteración nueva en vez de sobrescribir: ese es
    # el mecanismo entero por el que el historial sobrevive a los ciclos.
    def enter(stage, summary: nil, metric: nil)
      initiative.stage_entries.create!(
        stage: stage, iteration: initiative.iteration,
        qa_cycle: initiative.qa_cycles_consumed, status: :active,
        entered_at: Time.current, summary: summary, metric: metric)
    end

    def refresh_cache(stage:, status: :active)
      initiative.update!(current_stage: stage, current_stage_status: status,
                         stage_changed_at: Time.current)
    end

    def record_event(kind:, message:, **payload)
      Event.create!(
        occurred_at: Time.current, actor: actor,
        initiative: initiative, platform_client_id: initiative.platform_client_id,
        kind: kind, message: message, payload: payload)
    end

    def stage_label(stage) = stage.to_s.tr("_", " ").upcase
end
