# El seed de la maqueta: convierte `DesignSeed::Catalog` en filas.
#
# **Idempotente.** Correrlo dos veces deja exactamente el mismo estado, porque
# todo pasa por `find_or_create_by`. Eso importa más de lo que parece: un seed
# que solo funciona sobre base vacía obliga a destruirla para volver a verlo, y
# entonces deja de usarse.
#
# **Se niega a correr en producción.** `db/seeds.rb` se queda vacío por la misma
# razón: identia-platform ya documenta lo que cuesta un `db:seed` destructivo
# contra datos reales.
module DesignSeed
  Report = Data.define(:clients, :repositories, :initiatives, :artifacts,
                       :citations) do
    def to_s
      "#{clients} clientes · #{repositories} repositorios · " \
        "#{initiatives} evolutivos · #{artifacts} artefactos · " \
        "#{citations} citas"
    end
  end

  # Qué fixture del runtime sirve de cuerpo para cada tipo de artefacto. Así el
  # seed produce artefactos con citas de verdad en lugar de texto de relleno, y
  # el visor de F3 tiene algo que enseñar el primer día.
  BODIES = {
    dossier: %w[tank context], spec: %w[neo spec], dod: %w[seraph dod_pass],
    pkg: %w[trinity package], verify: %w[seraph verification],
    close: %w[link closure]
  }.freeze

  # Cuerpos sueltos que NO son fixtures de agente: versiones anteriores que el
  # seed materializa para que la cadena exista. Van aquí y no en
  # `lib/runtime/fixtures/`, cuyo inventario exacto afirma un test y cuyos
  # ficheros tienen que cumplir el contrato con el brain.
  BODIES_ROOT = Rails.root.join("lib/design_seed/bodies")

  module_function

  def call
    refuse_in_production!

    ActiveRecord::Base.transaction do
      Platform::Projection.import(Platform::FakeSource)
      seed_repositories
      Catalog::INITIATIVES.each { |data| seed_initiative(data) }
      seed_adrs
      seed_agent_configs
      Catalog::PACKAGES.each { |data| seed_gate_package(data) }
      seed_ev_031
      seed_closures
      seed_initiative_sources
      seed_quotes
      # Las citas que apuntaban a artefactos aún no publicados cuando se
      # escribieron. Es el caso normal, no una excepción del seed.
      Citations::Attach.resolve_pending
      seed_events
      align_sequences

      report
    end
  end

  # El contador de códigos, por encima de lo sembrado.
  #
  # La maqueta trae `ev-041` con su número escrito a mano, y el asignador reparte
  # desde cero. Sin esto, el primer alta pediría `ev-001` y seguiría subiendo
  # hasta chocar con un código sembrado — y el índice único de `initiatives.code`
  # haría fallar el alta con un error que no explica nada.
  #
  # Es lo único que el seed le dice al asignador, y solo hacia arriba: **el
  # contador no baja nunca**, porque un número ya repartido no se recicla.
  def align_sequences
    highest = Initiative.pluck(:code).map { |code| code.delete_prefix("ev-").to_i }.max.to_i
    sequence = MatrixSequence.find_or_create_by!(name: MatrixSequence::INITIATIVE)

    sequence.update!(last_number: highest) if sequence.last_number < highest
  end

  def refuse_in_production!
    return unless Rails.env.production?

    raise "matrix:seed_design no corre en producción: siembra datos de maqueta"
  end

  def report
    Report.new(clients: Platform::Client.count,
               repositories: Repository.count,
               initiatives: Initiative.count, artifacts: Artifact.count,
               citations: Citation.count)
  end

  # ── Los dos ejes ───────────────────────────────────────────────────────────

  def seed_repositories
    Catalog::REPOSITORIES.each do |data|
      client = client_for(data[:client])
      repository = Repository.find_or_initialize_by(
        platform_client_id: client.id, name: data[:name])
      repository.update!(data.except(:client, :name).merge(
                           last_synced_at: Time.current))
    end
  end

  def seed_initiative(data)
    initiative = Initiative.find_or_initialize_by(code: data[:code])
    client = client_for(data[:client])

    initiative.assign_attributes(
      platform_client_id: client.id,
      platform_project_id: Platform::Project.find_by(
        platform_id: data[:project])&.id,
      title: data[:title], opened_at: Time.zone.parse(data[:opened_on]),
      iteration: data[:iteration] || 1,
      qa_cycles_consumed: data[:qa_cycles] || 0)
    initiative.save!

    link_repositories(initiative, data)
    seed_stage_entries(initiative, data)
    seed_escalation(initiative, data)

    stage, status = StageCache.derive(initiative)
    initiative.update!(current_stage: stage, current_stage_status: status,
                       stage_changed_at: entered_current_stage_at(data))
  end

  # La EDAD que el dashboard pinta sale de aquí. La maqueta la trae en la marca
  # derecha del nodo activo —`3d`, `6h`, `25m`— y sin traducirla a una hora real
  # el dashboard enseñaría la fecha de apertura del evolutivo, que es otra cosa.
  DURATION = /\A(?<amount>\d+)(?<unit>[mhd])\z/

  def entered_current_stage_at(data)
    current = data[:pipe].find { |(status, _, _)| status == "act" } ||
              data[:pipe].reject { |(status, _, _)| FINISHED.include?(status) }.last ||
              data[:pipe].last
    match = DURATION.match(current[2].to_s)
    return Time.zone.parse(data[:opened_on]) if match.blank?

    Time.current - match[:amount].to_i.public_send(
      { "m" => :minutes, "h" => :hours, "d" => :days }.fetch(match[:unit]))
  end

  def seed_gate_package(data)
    initiative = Initiative.find_by!(code: data[:initiative])
    package = WorkPackage.find_or_initialize_by(code: data[:code])
    package.update!(
      initiative: initiative,
      tasks_count: data[:tasks_count], new_files_count: data[:new_files_count],
      modified_files_count: data[:modified_files_count],
      migrations_count: data[:migrations_count],
      sealed_at: initiative.stage_changed_at,
      content_hash: "sha256:#{Digest::SHA256.hexdigest(data[:code])}")

    WorkPackageRepository.find_or_initialize_by(
      work_package: package,
      repository: Repository.find_by!(
        platform_client_id: initiative.platform_client_id,
        name: data[:repository])
    ).update!(deploy_order: 1, write_scope: data[:write_scope])
  end

  def link_repositories(initiative, data)
    data[:repositories].each do |name|
      repository = Repository.find_by!(
        platform_client_id: initiative.platform_client_id, name: name)
      link = InitiativeRepository.find_or_initialize_by(
        initiative: initiative, repository: repository)
      link.update!(pinned_sha: data[:pinned][name],
                   indexed_files_count: repository.files_count,
                   indexed_at: initiative.opened_at,
                   decision_note: Catalog::DECISIONS[[ data[:code], name ]])
    end
  end

  # Las etapas PENDIENTES no generan fila: en este modelo pendiente es la
  # AUSENCIA de fila, y así lo lee `Pipeline::Glyph.strip`. Sembrar doce filas
  # por evolutivo dejaría a `StageCache.derive` eligiendo `publication` como
  # etapa actual de todo el mundo.
  #
  # **Una sola etapa queda abierta.** La maqueta pinta ▣ en el GATE 1 de ev-031
  # y de ev-014 aunque los dos estén firmados, igual que pinta » en nodos de
  # CLAUDE CODE ya terminados. Es el mismo resto, y tampoco se copia: aquí el
  # nodo `act` manda —es la etapa a la que se VOLVIÓ, y por eso gana a una
  # puerta anterior ya firmada—; si no hay ninguno, la actual es el último nodo
  # que no esté terminado. Todo lo demás queda cerrado.
  FINISHED = %w[done exec].freeze

  def seed_stage_entries(initiative, data)
    nodes = data[:pipe].each_with_index.map do |(status, summary, metric), i|
      { raw: status, stage: Initiative::STAGES[i],
        iteration: initiative.iteration,
        status: Catalog::STATUSES.fetch(status), summary: summary.presence,
        metric: metric.presence }
    end
    current = nodes.find { |n| n[:raw] == "act" } ||
              nodes.reject { |n| FINISHED.include?(n[:raw]) }.last ||
              nodes.last

    entries = Array(data[:prior]).map(&:symbolize_keys) + nodes
    entries.each do |attributes|
      open = attributes.equal?(current)
      write_entry(initiative, attributes, open: open)
    end
  end

  def write_entry(initiative, attributes, open:)
    entry = StageEntry.find_or_initialize_by(
      initiative: initiative, stage: attributes[:stage],
      iteration: attributes[:iteration])
    # Cerrar una etapa que quedó `active` la deja en `done`: activo y cerrado a
    # la vez no significa nada.
    status = if open then attributes[:status]
    elsif attributes[:status].to_s == "active" then :done
    else attributes[:status]
    end

    entry.update!(attributes.except(:raw).merge(
                    status: status, qa_cycle: initiative.qa_cycles_consumed,
                    entered_at: initiative.opened_at,
                    exited_at: open ? nil : initiative.opened_at + 1.hour))
  end

  def seed_escalation(initiative, data)
    return if data[:escalation].blank?

    Escalation.find_or_create_by!(initiative: initiative,
                                  reason: data[:escalation]) do |escalation|
      escalation.platform_client_id = initiative.platform_client_id
      escalation.opened_at = Time.current - 1.day
    end
  end

  def seed_adrs
    Catalog::ADRS.each do |data|
      repository = Repository.find_by!(name: data[:repository])
      adr = Adr.find_or_initialize_by(repository: repository,
                                      code: data[:code])
      adr.update!(title: data[:title], status: data[:status],
                  origin_initiative: Initiative.find_by(code: data[:initiative]))
    end
  end

  def seed_agent_configs
    Catalog::AGENT_CONFIGS.each do |agent, settings|
      AgentConfig.find_or_initialize_by(agent: agent, platform_client_id: nil)
                 .update!(settings: settings)
    end

    Catalog::AGENT_OVERRIDES.each do |data|
      AgentConfig.find_or_initialize_by(
        agent: data[:agent], platform_client_id: client_for(data[:client]).id
      ).update!(settings: data[:settings])
    end
  end

  # ── ev-031, el caso completo ───────────────────────────────────────────────

  def seed_ev_031
    initiative = Initiative.find_by!(code: "ev-031")
    runs = seed_runs(initiative)

    dossier = artifact_for(initiative, kind: :dossier, run: runs[:tank])
    spec = artifact_for(initiative, kind: :spec, version: 4, run: runs[:neo])

    # La v1 del DoD, la que MORFEO devolvió. El seed ya la narraba en dos sitios
    # —`summary: "v1 no traía c0"` en el prior de MORFEO, y el evento «se añade
    # el criterio c0 obligatorio» en la fixture de SERAPH— pero no existía como
    # fila. Sin ella el visor no tiene dos versiones que comparar, y la cadena
    # de versiones que el sistema afirma tener era una sola fila con un número
    # alto.
    artifact_for(initiative, kind: :dod, version: 1, run: runs[:seraph_dod],
                 derives_from: spec, body: BODIES_ROOT.join("dod-031-v1.md").read)

    dod_artifact = artifact_for(initiative, kind: :dod, version: 2,
                                run: runs[:seraph_dod], derives_from: spec)

    dod = seed_dod(initiative, dod_artifact, runs)
    report = seed_verification(initiative, dod, runs)
    package = seed_package(initiative, runs)
    signature = seed_signature(initiative, package)
    seed_test_guide(initiative, dod, report, runs)
    attach_verdicts(report, dod)
    seed_conflict(dossier, package_artifact(initiative, runs))

    signature
  end

  def seed_runs(initiative)
    Pipeline::STAGE_WORK.to_h do |stage, work|
      run = AgentRun.find_or_create_by!(
        code: "#{work[:agent]}/run-#{initiative.number}-#{work[:purpose]}"
      ) do |created|
        created.initiative = initiative
        created.agent = work[:agent]
        created.purpose = work[:purpose]
        created.status = :ok
        created.iteration = initiative.iteration
        created.started_at = initiative.stage_changed_at || initiative.opened_at
        created.finished_at = created.started_at + 4.minutes
        created.input_tokens = 18_400
        created.output_tokens = 3_120
      end

      [ stage.to_sym, run ]
    end
  end

  def seed_dod(initiative, artifact, runs)
    dod = DefinitionOfDone.find_or_initialize_by(
      initiative: initiative, code: "dod-031", version: 2)
    dod.update!(authored_by_run: runs[:seraph_dod], artifact: artifact,
                # Invariante 5: sin revisión de MORFEO no se pasa a plan.
                reviewed_by_run: runs[:morfeo])

    Catalog::DOD_031.each do |data|
      criterion = DodCriterion.find_or_initialize_by(
        definition_of_done: dod, key: data[:key])
      criterion.update!(
        statement: data[:statement], critical: data[:critical] || false,
        mandatory_kind: data[:mandatory_kind],
        repository: repository_named(data[:repository], initiative),
        test_ref: data[:test_ref],
        trace_citation: citation_for(artifact, data[:trace], initiative))
    end

    dod
  end

  def seed_verification(initiative, dod, runs)
    artifact = artifact_for(initiative, kind: :verify, round: 2,
                            run: runs[:seraph_verification])
    report = VerificationReport.find_or_initialize_by(code: "verify-031-r2")
    report.update!(initiative: initiative, definition_of_done: dod,
                   agent_run: runs[:seraph_verification], artifact: artifact,
                   iteration: initiative.iteration, qa_cycle: 2,
                   outcome: :conforme)

    Catalog::CI_031.each do |data|
      check = CiCheck.find_or_initialize_by(
        verification_report: report,
        repository: repository_named(data[:repository], initiative))
      check.update!(data.except(:repository).merge(
                      checks_failed: 0, tests_failed: 0))
    end

    report
  end

  def attach_verdicts(report, dod)
    Catalog::DOD_031.each do |data|
      criterion = dod.dod_criteria.find_by!(key: data[:key])
      verdict = Verdict.find_or_initialize_by(verification_report: report,
                                              dod_criterion: criterion)
      verdict.update!(
        result: data[:verdict], evidence: data[:evidence],
        evidence_citation: citation_for(report.artifact,
                                        data[:evidence_citation],
                                        report.initiative),
        # Los ⊗ no llevan evidencia: llevan redirección al paso que los cubre.
        guide_step: guide_step_at(report.initiative, data[:guide_step]))
    end
  end

  def seed_package(initiative, runs)
    data = Catalog::PKG_045
    package = WorkPackage.find_or_initialize_by(code: data[:code])
    package.update!(
      initiative: initiative, agent_run: runs[:trinity],
      artifact: package_artifact(initiative, runs),
      tasks_count: data[:tasks_count], new_files_count: data[:new_files_count],
      modified_files_count: data[:modified_files_count],
      migrations_count: data[:migrations_count],
      sealed_at: data[:signed_at] - 1.day,
      content_hash: "sha256:#{Digest::SHA256.hexdigest(data[:code])}")

    data[:steps].each do |step|
      row = WorkPackageRepository.find_or_initialize_by(
        work_package: package,
        repository: repository_named(step[:repository], initiative))
      row.update!(deploy_order: step[:deploy_order],
                  write_scope: step[:write_scope],
                  compatibility_note: step[:note])
    end

    package
  end

  # GATE 1 es irreversible: la firma no se puede modificar, así que solo se crea
  # si no está. Correr el seed dos veces no la reescribe — no podría.
  def seed_signature(initiative, package)
    data = Catalog::PKG_045
    signer = Platform::User.find_by!(platform_id: 1)

    signature = GateSignature.find_or_create_by!(work_package: package) do |row|
      row.initiative = initiative
      row.package_hash = package.content_hash
      row.signed_by_user = signer
      row.identity = signer.identity_snapshot
      row.signed_at = data[:signed_at]
      row.statement = data[:statement]
    end

    data[:steps].each do |step|
      commit = GateSignatureCommit.find_or_initialize_by(
        gate_signature: signature,
        repository: repository_named(step[:repository], initiative))
      commit.update!(base_sha: step[:base_sha],
                     executed_sha: step[:executed_sha],
                     write_scope: step[:write_scope],
                     deploy_order: step[:deploy_order],
                     executed_confirmed_by: signer,
                     executed_confirmed_at: data[:signed_at] + 2.days)
    end

    signature
  end

  def seed_test_guide(initiative, dod, report, runs)
    guide = TestGuide.find_or_initialize_by(code: "guia-pruebas-031")
    guide.update!(initiative: initiative, verification_report: report,
                  artifact: guide_artifact(initiative, runs))

    Catalog::GUIDE_031.each do |data|
      step = GuideStep.find_or_initialize_by(test_guide: guide,
                                             position: data[:position])
      step.update!(
        title: data[:title], body: data[:body],
        evidence_origin: data[:evidence_origin],
        dod_criterion: dod.dod_criteria.find_by(key: data[:criterion]),
        walked_at: data[:walked] ? report.created_at : nil,
        walked_by_user: data[:walked] ? Platform::User.find_by(platform_id: 1) : nil)
    end

    guide
  end

  # El conflicto de nivel: una cita DERIVADA que contradice a su ORIGEN. Gana el
  # origen, siempre — y el artefacto que hizo la afirmación derivada queda
  # marcado para revisión, sin tocar su fila.
  def seed_conflict(origin_artifact, derived_artifact)
    initiative = derived_artifact.initiative
    origin = citation_for(origin_artifact, "[src:meet/2026-05-02@22:40]",
                          initiative)
    derived = citation_for(derived_artifact, "[src:dod/dod-031#c3]",
                           initiative)
    return if origin.blank? || derived.blank?

    CitationConflict.find_or_create_by!(derived_citation: derived,
                                        origin_citation: origin) do |conflict|
      conflict.detected_at = Time.current - 6.hours
      conflict.flagged_artifact = derived_artifact
    end
  end

  # ── Artefactos y citas ─────────────────────────────────────────────────────

  # `number:` existe porque NO todos los artefactos llevan el número de su
  # evolutivo: el paquete tiene secuencia propia (ev-031 → PKG-045), como
  # documenta Artifacts::Key. Componerlo siempre con `initiative.number` dejaba
  # un `pkg-031` contra el que la cita `[src:pkg/pkg-045#deploy]` —la traza del
  # c0 del DoD— no resolvía. Se vio al escribir Citations::Resolve.
  # Publicar es siempre por `Artifacts::Publish`. Lo que este método añade es
  # la IDEMPOTENCIA, que es propia del seed y no del sistema: en producción
  # publicar dos veces la misma clave es un error, y aquí es lo normal.
  #
  # `produced_at: initiative.opened_at` y no `Time.current`: el cuerpo del
  # artefacto lleva la fecha dentro, así que con la hora actual cada resiembra
  # produciría bytes distintos para la misma clave y cualquier comparación de
  # documentos se volvería intermitente.
  def artifact_for(initiative, kind:, run:, version: 1, round: nil,
                   derives_from: nil, number: nil, body: nil)
    code = Artifacts::Key.code(kind: kind, number: number || initiative.number,
                               round: round)
    key = Artifacts::Key.build(client: initiative.platform_client.slug,
                               initiative: initiative.code, code: code,
                               version: version)
    body ||= body_for(kind, initiative)

    # Un artefacto ya sembrado no se reescribe —es inmutable— pero SÍ se le
    # vuelven a atar las citas. El cuerpo es el mismo, así que las citas son las
    # mismas; lo que cambia es contra qué resuelven, porque una fuente que no
    # existía en la pasada anterior puede existir ahora. Sin esto, una base de
    # desarrollo se queda con `target` nulo para siempre y ningún test se entera:
    # los tests arrancan limpios.
    existing = Artifact.find_by(storage_key: key)
    if existing
      Citations::Attach.body(citable: existing, body: body,
                             client: initiative.platform_client_id)
      return existing
    end

    Artifacts::Publish.call(
      initiative: initiative, kind: kind, body: body, version: version,
      round: round, number: number, derives_from: derives_from,
      produced_by_run: run, produced_at: initiative.opened_at).artifact
  end

  def body_for(kind, initiative)
    return closure_body(initiative) if kind.to_sym == :close

    agent, purpose = BODIES[kind.to_sym]
    return guide_body if agent.blank?

    _metadata, body = Runtime::Fixture.read(agent: agent, purpose: purpose)
    body.gsub("{{initiative}}", initiative.code)
        .gsub("{{title}}", initiative.title)
        .gsub("{{client}}", initiative.platform_client.slug)
  end

  def guide_body
    steps = Catalog::GUIDE_031.map do |step|
      "## #{format('%02d', step[:position])} · #{step[:title]}\n\n#{step[:body]}"
    end

    "# Guía de pruebas manuales · ev-031\n\n#{steps.join("\n\n")}\n"
  end

  # La frase que cada cita afirma estar citando. Va en una pasada aparte porque
  # las citas nacen de PARSEAR el cuerpo, y el cuerpo no dice qué frase de la
  # fuente se está citando — solo qué párrafo. En F9 la declara el agente.
  def seed_quotes
    Catalog::QUOTES.each do |raw, quote|
      Citation.where(raw: raw).update_all(quote: quote)
    end
  end

  # El ámbito documental de cada evolutivo. Es un FILTRO: lo que NO está aquí
  # no desaparece, se hereda del cliente. Por eso `acta-precios` aparece en dos
  # evolutivos sin duplicarse en ninguno — un documento vive una sola vez.
  def seed_initiative_sources
    Catalog::INITIATIVE_SOURCES.each do |data|
      initiative = Initiative.find_by(code: data[:initiative])
      source = if data[:doc]
        Platform::Document.find_by(slug: data[:doc])
      else
        Platform::Meeting.find_by(slug: data[:meet])
      end
      next if initiative.blank? || source.blank?

      row = InitiativeSource.find_or_initialize_by(initiative: initiative,
                                                   source: source)
      row.update!(refs_count: data[:refs])
    end
  end

  # Los cierres de los evolutivos publicados. Es lo que convierte la memoria
  # entre evolutivos en algo que se puede citar: sin `close-002` en el bucket,
  # `[src:close/close-002#§3]` no resuelve contra nada y la afirmación de que
  # ev-031 revierte una decisión de ev-002 no es comprobable.
  def seed_closures
    Catalog::CLOSURES.each do |data|
      initiative = Initiative.find_by(code: data[:initiative])
      next if initiative.blank?

      # LINK, que es quien redacta el cierre. `Pipeline::STAGE_WORK` no tiene
      # entrada para `publication` —la etapa 12 no ejecuta ningún agente, solo
      # deja constancia—, así que pedir ahí un run devolvía nil y los cierres
      # nacían sin productor. No se veía porque el front-matter nunca se
      # renderizaba; `Artifacts::Publish` lo destapó al validarlo.
      artifact_for(initiative, kind: :close, run: seed_runs(initiative)[:link])
    end
  end

  def closure_body(initiative)
    data = Catalog::CLOSURES.find { |row| row[:initiative] == initiative.code }
    return "# Cierre · #{initiative.code}\n" if data.blank?

    code = "[src:code/#{data[:repository]}:src/index.ts#L1@#{data[:sha]}]"

    <<~MARKDOWN
      # Cierre · #{initiative.code} · #{initiative.title}

      ## §1 · Qué se pidió y qué se construyó

      #{data[:what]} #{code}

      ## §2 · Decisiones y quién las tomó

      #{data[:decision]}

      ## §3 · Lo que este evolutivo dejó fuera

      #{data[:price]}
    MARKDOWN
  end

  # El artefacto del paquete, con el número de la secuencia de paquetes y no el
  # del evolutivo. Se pide desde dos sitios y `artifact_for` es idempotente por
  # `storage_key`, así que la segunda llamada devuelve el mismo.
  def package_artifact(initiative, runs)
    artifact_for(initiative, kind: :pkg, run: runs[:trinity],
                 number: Catalog::PKG_045[:number])
  end

  def guide_artifact(initiative, runs)
    artifact_for(initiative, kind: :guide, run: runs[:seraph_verification])
  end

  # Las citas salen de PARSEAR el cuerpo, no de una lista aparte, y de eso se
  # encarga Citations::Attach — el único sitio del sistema donde se crea una
  # cita. Hasta F4 esta lógica vivía aquí duplicada y en pipeline_walk.rb, y ya
  # había divergido.
  def citation_for(artifact, raw, initiative, quote: nil)
    return nil if artifact.blank?

    Citations::Attach.one(citable: artifact, raw: raw, quote: quote,
                          client: initiative.platform_client_id)
  end

  # ── El event stream ────────────────────────────────────────────────────────

  def seed_events
    [
      [ "LINK", "vivla", "ev-027", "close-027 v1 en redacción · 2 desvíos" ],
      [ "GATE 1", "vivla", "ev-031",
        "firmado por ap@identia · 3 commits sellados" ],
      [ "TRINITY", "caser", "ev-041", "PKG-031 sellado · espera firma" ],
      [ "SERAPH", "mango", "ev-024", "?3 · entorno inestable · escalado" ],
      [ "TANK", "cirsa", "ev-038", "indexando · 1.204/3.900 ficheros" ],
      [ "SYNC", "vivla", nil, sync_message("vivla") ]
    ].each_with_index do |(actor, client, code, message), index|
      # Se deduplica por QUIÉN y SOBRE QUÉ, no por el texto. Con la clave en el
      # mensaje, cambiarlo AÑADE un evento en vez de sustituirlo: la base de
      # desarrollo acumula las dos versiones y en CI no se ve, porque los tests
      # arrancan limpios.
      event = Event.find_or_initialize_by(
        actor: actor, platform_client: client_for(client),
        initiative: code && Initiative.find_by(code: code))

      event.occurred_at ||= Time.current - (index + 1).hours
      event.update!(kind: "activity", message: message)
    end
  end

  def sync_message(slug)
    client = client_for(slug)
    documents = Platform::Document.where(platform_client_id: client.id).count
    meetings = Platform::Meeting.where(platform_client_id: client.id).count

    "#{documents} documentos · #{meetings} transcripciones"
  end

  # ── Utilidades ─────────────────────────────────────────────────────────────

  def client_for(slug) = Platform::Client.find_by!(slug: slug)

  def repository_named(name, initiative)
    return nil if name.blank?

    Repository.find_by(platform_client_id: initiative.platform_client_id,
                       name: name)
  end

  def guide_step_at(initiative, position)
    return nil if position.blank?

    TestGuide.find_by(initiative: initiative)
             &.guide_steps&.find_by(position: position)
  end
end
