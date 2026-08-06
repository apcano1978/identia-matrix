# El glifo se DERIVA de (etapa, estado); no se guarda.
#
# Guardarlo sería tener el símbolo en un sitio y el estado en otro, y el día que
# discreparan ganaría el símbolo — que es el dato que no significa nada.
module Pipeline::Glyph
  PENDING = "○".freeze
  DONE = "●".freeze
  FAILED = "✕".freeze
  ESCALATED = "⊘".freeze
  ACTIVE = "◆".freeze

  # Tres etapas tienen glifo propio mientras están activas, porque las tres son
  # esperas de naturaleza distinta y la tira de doce lo enseña de un vistazo.
  ACTIVE_BY_STAGE = {
    "gate_1" => "▣",         # esperando una firma
    "gate_2" => "▤",         # esperando una validación
    "claude_code" => "»"     # ejecutando fuera de matrix
  }.freeze

  module_function

  def for(stage:, status:)
    case status.to_s
    when "pending" then PENDING
    when "done" then DONE
    when "failed" then FAILED
    when "escalated" then ESCALATED
    when "active" then ACTIVE_BY_STAGE.fetch(stage.to_s, ACTIVE)
    else
      raise ArgumentError, "estado desconocido: #{status.inspect}"
    end
  end

  # La tira de doce de un evolutivo, en orden. Toma la ÚLTIMA iteración de cada
  # etapa: lo que la maqueta pinta es dónde está ahora, no cada vuelta.
  def strip(initiative)
    latest = initiative.stage_entries.group_by(&:stage).transform_values do |es|
      es.max_by(&:iteration)
    end

    Initiative::STAGES.map do |stage|
      entry = latest[stage]
      next self.for(stage: stage, status: :pending) if entry.blank?

      self.for(stage: stage, status: entry.status)
    end
  end
end
