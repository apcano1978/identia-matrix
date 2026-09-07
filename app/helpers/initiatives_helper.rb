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

  # Las cuatro pestañas de evidencia. Desde F6 cada una lleva a SU pantalla y no
  # a seleccionar un artefacto en el visor: el DoD, el informe y la guía tienen
  # contadores, veredictos y cobertura que un visor de markdown no puede dar.
  #
  # `acta` va la PRIMERA porque es la primera de la cadena: de ella salen la spec
  # y, de ahí, todo lo demás. Cuál se apaga y cuándo lo decide `tab_enabled?`,
  # donde el acta es la excepción y está razonada.
  ARTIFACT_TABS = { "acta" => :acta, "dod" => :dod, "verify" => :verify,
                    "guide" => :guide }.freeze

  # ⚠ Por el PROYECTO, no por el cliente del evolutivo. Ver `tray_destination`
  # en `dashboard_helper`: es el mismo arreglo y por la misma razón, y aquí lo
  # que se cae con un proyecto propio es la ficha del evolutivo.
  def artifact_tabs(initiative, artifacts, selected)
    project = initiative.project

    ARTIFACT_TABS.map do |label, kind|
      artifact = artifacts.find { |a| a.kind == kind.to_s }

      { label: label, artifact: artifact, current: artifact == selected,
        enabled: tab_enabled?(label, artifact, initiative),
        path: evidence_path_for(label, project, initiative) }
    end
  end

  # Una pestaña se apaga cuando su artefacto no existe: llevar a una pantalla
  # vacía es peor que decir que no hay nada.
  #
  # ⚠ EL ACTA ES LA EXCEPCIÓN, y desde B9 tiene que serlo. Su pantalla es donde
  # se HABLA con el ARQUITECTO, así que existe antes que el artefacto y
  # precisamente para producirlo: apagarla hasta que hubiera acta dejaría la
  # conversación sin puerta.
  #
  # Solo en `need`, que es donde esa conversación ocurre. Un evolutivo que ya
  # pasó de ahí sin acta —los abiertos antes de F11— no va a tener ninguna, y su
  # pestaña se queda apagada como las otras tres.
  def tab_enabled?(label, artifact, initiative)
    return true if artifact

    label == "acta" && initiative.at_need?
  end

  def evidence_path_for(label, project, initiative)
    case label
    when "acta" then project_initiative_acta_path(project, initiative)
    when "dod" then project_initiative_definition_of_done_path(project, initiative)
    when "verify" then project_initiative_verification_path(project, initiative)
    else project_initiative_guide_path(project, initiative)
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
