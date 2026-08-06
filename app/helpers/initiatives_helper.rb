# frozen_string_literal: true

module InitiativesHelper
  Node = Data.define(:position, :stage, :label, :status, :summary, :metric,
                     :current) do
    def current? = current
  end

  # Los doce nodos, siempre los doce. Una etapa sin fila es PENDIENTE — en este
  # modelo pendiente es la ausencia de fila, y el nodo lo dice igual.
  def pipeline_nodes(initiative)
    latest = Pipeline::Glyph.latest_entries(initiative)

    Initiative::STAGES.each_with_index.map do |stage, index|
      entry = latest[stage]

      Node.new(position: index + 1, stage: stage, label: stage_label(stage),
               status: entry&.status || "pending", summary: entry&.summary,
               metric: entry&.metric,
               current: stage == initiative.current_stage)
    end
  end

  Arc = Data.define(:label, :colour)

  # El arco de ciclo QA: un SVG punteado del nodo 9 al 3. Solo se pinta si hubo
  # retorno, y su color dice si el ciclo sigue abierto o ya se resolvió — que es
  # la diferencia entre «esto está fallando» y «esto falló y se arregló».
  def qa_arc(initiative)
    consumed = initiative.qa_cycles_consumed
    return nil unless consumed.positive?

    if initiative.awaiting_human? || initiative.at_publication?
      Arc.new(label: "↺ ciclo #{consumed} · resuelto", colour: "#5F6B5F")
    else
      Arc.new(label: "↺ #{consumed}/#{Initiative::MAX_QA_CYCLES}", colour: "#C98070")
    end
  end

  Banner = Data.define(:glyph, :text, :tone)

  # El aviso del ciclo. Sale de los VEREDICTOS del último informe, no de un
  # texto guardado: si mañana cambia el dictamen, el aviso cambia con él.
  def cycle_banner(initiative, report)
    return nil if report.blank? || initiative.qa_cycles_consumed.zero?

    counts = report.verdict_counts
    if report.outcome_conforme?
      Banner.new(glyph: "▤", tone: :ok, text:
        "ciclo QA #{initiative.qa_cycles_consumed}/#{Initiative::MAX_QA_CYCLES} · " \
        "SERAPH dio conforme#{unsupported_note(report, counts)}")
    else
      Banner.new(glyph: "↺", tone: :fail, text:
        "ciclo QA #{initiative.qa_cycles_consumed}/#{Initiative::MAX_QA_CYCLES} · " \
        "SERAPH devolvió #{pluralize(counts['unmet'].to_i, 'incumplimiento')} del DoD")
    end
  end

  # Las pestañas del artefacto. Deshabilitada = el evolutivo todavía no tiene
  # ese artefacto, y se pinta apagada en vez de llevar a una pantalla vacía.
  ARTIFACT_TABS = { "dod" => :dod, "verify" => :verify, "guide" => :guide }.freeze

  def artifact_tabs(initiative, artifacts, selected)
    ARTIFACT_TABS.map do |label, kind|
      artifact = artifacts.find { |a| a.kind == kind.to_s }

      { label: label, artifact: artifact, current: artifact == selected }
    end
  end

  def artifact_run_label(artifact)
    run = artifact.produced_by_run
    return "sin ejecución registrada" if run.blank?

    "#{run.code} · v#{artifact.version}"
  end

  private
    def unsupported_note(report, counts)
      unsupported = report.unsupported_verdicts
      return "" if unsupported.empty?

      keys = unsupported.map { |v| v.dod_criterion.key }.sort.to_sentence
      " · #{keys} #{unsupported.one? ? 'queda' : 'quedan'} ⊗ y " \
        "#{unsupported.one? ? 'solo lo cubre' : 'solo los cubre'} la guía"
    end
end
