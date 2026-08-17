# Recorre un evolutivo por las doce etapas con el runtime falso, de consola.
#
# No es un test: es la forma de MIRAR el sistema funcionando antes de que exista
# una pantalla. Cada variante fuerza una de las bifurcaciones, y lo que hay que
# leer en la salida es qué contador sube y cuál no — que es donde está la
# diferencia entre los cuatro veredictos.
#
#   bin/rails "matrix:walk_pipeline[ev-999]"
#   bin/rails "matrix:walk_pipeline[ev-999,fail-once]"
#
# Usa los servicios de verdad —`Pipeline::Advance`, `SendBack`, `Escalate`— y no
# atajos: si una precondición falta, el recorrido se para igual que se pararía
# en producción.
module PipelineWalk
  VARIANTS = {
    "happy" => "las doce etapas encadenan",
    "fail-once" => "un ✕ vuelve a NEO y sube los DOS contadores",
    "reject-gate-2" => "un rechazo vuelve a NEO y sube solo `iteration`",
    "return-to-trinity" => "GATE 1 devuelve a TRINITY con nota de ORIGEN",
    "exhaust" => "dos ✕ seguidos detienen con escalada",
    "inconclusive" => "tres ? escalan SIN consumir ciclo"
  }.freeze

  # Un recorrido no puede dar más vueltas que esto. Si las da, hay un ciclo que
  # no converge y es mejor saberlo que esperar.
  MAX_STEPS = 60

  Result = Data.define(:initiative, :variant, :log) do
    def halted? = initiative.status_escalated?
  end

  class << self
    def call(code:, variant: "happy", client_slug: "vivla", io: nil)
      new(code: code, variant: variant, client_slug: client_slug, io: io).call
    end

    def new(...) = Walk.new(...)
  end

  class Walk
    def initialize(code:, variant:, client_slug:, io:)
      unless VARIANTS.key?(variant)
        raise ArgumentError,
              "variante desconocida: #{variant}. Hay #{VARIANTS.keys.join(', ')}"
      end

      @variant = variant
      @code = code
      @client = Platform::Client.find_by(slug: client_slug)
      @io = io
      @log = []
      @passes = Hash.new(0)
    end

    def call
      if @client.blank?
        raise "no hay cliente `vivla`: corre antes bin/rails matrix:seed_design"
      end

      initiative = prepare
      drive(initiative)

      Result.new(initiative: initiative.reload, variant: @variant, log: @log)
    end

    private
      attr_reader :variant, :log

      def prepare
        initiative = Initiative.find_or_create_by!(code: @code) do |created|
          created.platform_client = @client
          created.title = "Recorrido de prueba · #{variant}"
          created.opened_at = Time.current
        end

        @client.repositories.order(:name).each_with_index do |repository, index|
          InitiativeRepository.find_or_create_by!(
            initiative: initiative, repository: repository
          ) { |link| link.pinned_sha = repository.head_sha || "0000000" }
          break if index >= 1 # dos repositorios: hay ventana de convivencia
        end

        say "#{initiative.code} · #{VARIANTS.fetch(variant)}"
        initiative
      end

      # El bucle es el que tendrá el dispatcher de F9: mira dónde está y hace lo
      # que toca. Aquí las decisiones humanas las toma la variante.
      def drive(initiative)
        MAX_STEPS.times do
          return if published?(initiative) || initiative.status_escalated?

          step(initiative)
          initiative.reload
        end

        raise "#{initiative.code} no converge en #{MAX_STEPS} pasos"
      end

      def step(initiative)
        case initiative.current_stage
        when "need" then advance(initiative)
        when "publication" then publish(initiative)
        when "gate_1" then gate_1(initiative)
        when "claude_code" then claude_code(initiative)
        when "seraph_verification" then verify(initiative)
        when "gate_2" then gate_2(initiative)
        else agent_stage(initiative)
        end
      end

      # ── Las etapas de agente ─────────────────────────────────────────────

      def agent_stage(initiative)
        stage = initiative.current_stage
        work = Pipeline::STAGE_WORK.fetch(stage)
        @passes[stage] += 1
        result = run_agent(initiative, work, @passes[stage])

        case stage
        when "seraph_dod" then write_dod(initiative, result)
        when "morfeo" then review(initiative, result)
        when "trinity" then seal(initiative, result)
        end

        advance(initiative) unless initiative.reload.current_stage != stage
      end

      def run_agent(initiative, work, pass)
        run = AgentRun.create!(
          initiative: initiative, agent: work[:agent], purpose: work[:purpose],
          iteration: initiative.iteration,
          qa_cycle: initiative.qa_cycles_consumed,
          code: "#{work[:agent]}/#{initiative.code}-#{work[:purpose]}-#{pass}",
          status: :running, started_at: Time.current)

        result = Runtime.run(run)
        run.update!(status: :ok, finished_at: Time.current,
                    input_tokens: result.input_tokens,
                    output_tokens: result.output_tokens,
                    brain_request_id: result.request_id)
        store(initiative, run, result, pass)

        result
      end

      # El artefacto va al bucket por `Artifacts::Publish`, igual que en el
      # sistema real: con su clave inmutable, su front-matter y sus citas
      # parseadas del cuerpo.
      #
      # Hasta F5 este método publicaba por su cuenta y **no rellenaba la columna
      # `front_matter`**: los artefactos del paseo salían con `{}` dentro, y no
      # lo miraba nadie.
      def store(initiative, run, result, version)
        kind = artifact_kind(run)
        return nil if kind.blank?

        round = kind == :verify ? initiative.qa_cycles_consumed + 1 : nil
        code = Artifacts::Key.code(kind: kind, number: initiative.number,
                                   round: round)
        key = Artifacts::Key.build(client: @client.slug,
                                   initiative: initiative.code, code: code,
                                   version: version)
        return Artifact.find_by(storage_key: key) if Artifact.exists?(storage_key: key)

        artifact = Artifacts::Publish.call(
          initiative: initiative, kind: kind, body: result.body,
          version: version, round: round, produced_by_run: run,
          produced_at: run.started_at || initiative.opened_at).artifact
        say "  #{run.code} → #{key}"

        artifact
      end

      ARTIFACT_KINDS = {
        "context" => :dossier, "spec" => :spec, "dod_pass" => :dod,
        "package" => :pkg, "verification" => :verify, "closure" => :close
      }.freeze

      def artifact_kind(run) = ARTIFACT_KINDS[run.purpose]

      def write_dod(initiative, result)
        version = @passes["seraph_dod"]
        dod = DefinitionOfDone.create!(
          initiative: initiative, code: "dod-#{initiative.number}",
          version: version, artifact: Artifact.find_by(
            initiative: initiative, kind: :dod, version: version))

        result.findings.select { |f| f["kind"] == "criterion" }
              .each do |finding|
          DodCriterion.create!(
            definition_of_done: dod, key: finding["reference"],
            statement: finding["statement"],
            repository: @client.repositories.find_by(name: finding["repository"]),
            critical: finding["repository"].blank?,
            mandatory_kind: finding["reference"] == "c0" ? :multi_repo_compatibility : nil)
        end

        say "  dod-#{initiative.number} v#{version} · #{dod.criteria_count} criterios"
      end

      # MORFEO devuelve a quien puede corregirlo: la spec la escribe NEO y el
      # DoD lo escribe SERAPH. No rehacer la spec para arreglar un criterio que
      # falta es justo el caso de la maqueta.
      def review(initiative, result)
        dod = latest_dod(initiative)

        if result.blockers.any? && @passes["morfeo"] == 1 && variant == "happy"
          # Incluso en el recorrido feliz MORFEO devuelve una vez: es lo que
          # hace su fixture, y es lo que enseña que el bucle no consume QA.
          send_back(initiative, to: :seraph_dod, actor: "MORFEO")
          return
        end

        dod.update!(reviewed_by_run: initiative.agent_runs
                                                .where(agent: :morfeo).last)
        say "  MORFEO revisó dod-#{initiative.number} v#{dod.version}"
      end

      def seal(initiative, result)
        package = WorkPackage.create!(
          initiative: initiative,
          code: "pkg-#{initiative.number}-#{@passes['trinity']}",
          agent_run: initiative.agent_runs.where(agent: :trinity).last,
          tasks_count: 19, sealed_at: Time.current,
          content_hash: "sha256:#{SecureRandom.hex(8)}")

        initiative.repositories.order(:name).each_with_index do |repository, i|
          WorkPackageRepository.create!(
            work_package: package, repository: repository,
            deploy_order: i + 1,
            compatibility_note: result.findings.dig(i, "statement"))
        end

        say "  #{package.code} sellado · #{package.work_package_repositories.count} repos en orden"
      end

      # ── Las dos puertas y la ejecución ───────────────────────────────────

      def gate_1(initiative)
        @passes["gate_1"] += 1

        if variant == "return-to-trinity" && @passes["gate_1"] == 1
          note = human_note(initiative, "El orden de despliegue invierte los " \
                                        "dos primeros repositorios.")
          send_back(initiative, to: :trinity, actor: signer.to_s,
                    human_note: note)
          return
        end

        sign(initiative)
        advance(initiative)
      end

      def sign(initiative)
        package = initiative.work_packages.order(:sealed_at).last
        signature = GateSignature.create!(
          initiative: initiative, work_package: package,
          package_hash: package.content_hash, signed_by_user: signer,
          identity: signer.identity_snapshot, signed_at: Time.current,
          statement: "Autorizo ejecutar #{package.code} sobre " \
                     "#{package.repositories.count} repositorios.")

        package.deploy_sequence.each do |row|
          GateSignatureCommit.create!(
            gate_signature: signature, repository: row.repository,
            base_sha: row.repository.head_sha || "0000000",
            write_scope: row.write_scope, deploy_order: row.deploy_order)
        end

        say "  GATE 1 firmado por #{signature.identity} · " \
            "#{signature.gate_signature_commits.count} commits"
      end

      # Matrix no ejecuta: registra que alguien ejecutó. Invariante 2.
      def claude_code(initiative)
        signature = initiative.gate_signatures.order(:signed_at).last
        signature.gate_signature_commits.each do |commit|
          commit.update!(executed_sha: SecureRandom.hex(4)[0, 7],
                         executed_confirmed_by: signer,
                         executed_confirmed_at: Time.current)
        end

        say "  Claude Code ejecutó · #{signature.gate_signature_commits.count} commits confirmados"
        advance(initiative)
      end

      def gate_2(initiative)
        @passes["gate_2"] += 1
        guide = initiative.test_guides.order(:id).last

        if variant == "reject-gate-2" && @passes["gate_2"] == 1
          GateValidation.create!(
            initiative: initiative, test_guide: guide, decision: :rejected,
            decided_by_user: signer, decided_at: Time.current,
            coverage_snapshot: guide.coverage,
            rejection_note: "El importe se sigue redondeando en el cliente.")
          say "  GATE 2 RECHAZADO · vuelve a NEO sin consumir ciclo de QA"
          send_back(initiative, to: :neo, actor: signer.to_s)
          return
        end

        walk_guide(guide)
        GateValidation.create!(
          initiative: initiative, test_guide: guide, decision: :validated,
          decided_by_user: signer, decided_at: Time.current,
          coverage_snapshot: guide.reload.coverage)
        say "  GATE 2 validado · #{guide.coverage[:walked]}/#{guide.coverage[:total]} pasos"
        advance(initiative)
      end

      def walk_guide(guide)
        guide.guide_steps.each do |step|
          step.update!(walked_at: Time.current, walked_by_user: signer,
                       walk_note: "Recorrido en el walk de #{variant}")
        end
      end

      # ── La verificación, que es donde viven los cuatro veredictos ────────

      def verify(initiative)
        @passes["seraph_verification"] += 1
        work = Pipeline::STAGE_WORK.fetch("seraph_verification")
        run_agent(initiative, work, @passes["seraph_verification"])

        dod = latest_dod(initiative)
        report = build_report(initiative, dod)
        say "  #{report.code} · #{report.verdict_counts.sort.to_h} · " \
            "consume ciclo: #{report.consumes_cycle?}"

        outcome(initiative, report)
      end

      def build_report(initiative, dod)
        report = VerificationReport.create!(
          initiative: initiative, definition_of_done: dod,
          code: "verify-#{initiative.number}-r#{@passes['seraph_verification']}",
          agent_run: initiative.agent_runs.where(agent: :seraph).last,
          iteration: initiative.iteration,
          qa_cycle: initiative.qa_cycles_consumed,
          artifact: initiative.artifacts.where(kind: :verify).order(:id).last)

        dod.dod_criteria.each_with_index do |criterion, index|
          Verdict.create!(verification_report: report, dod_criterion: criterion,
                          result: verdict_for(criterion, index),
                          evidence: "recorrido #{variant}")
        end

        report.reload
      end

      # La única decisión que distingue las seis variantes.
      def verdict_for(criterion, index)
        case variant
        when "inconclusive" then :inconclusive
        when "exhaust" then index.zero? ? :unmet : :met
        when "fail-once"
          @passes["seraph_verification"] == 1 && index.zero? ? :unmet : :met
        else
          criterion.repository.blank? ? :unsupported : :met
        end
      end

      def outcome(initiative, report)
        # Ningún ✕ y nada que un humano no pueda cubrir: conforme.
        return conforme(initiative, report) unless returned?(report)

        # `?` no es `✕`: no hay nada que corregir, falló el entorno. Escala sin
        # consumir ciclo, que es el invariante 7 por su otro lado.
        if report.verdicts.all?(&:inconclusive?)
          report.update!(outcome: :escalated)
          Pipeline::Escalate.call(initiative: initiative, actor: "SERAPH",
                                  reason: "inconclusive_environment",
                                  verification_report: report)
          say "  ESCALADO · entorno · qa_cycles sigue en " \
              "#{initiative.reload.qa_cycles_consumed}"
          return
        end

        report.update!(outcome: :returned)
        result = Pipeline::SendBack.call(initiative: initiative, to: :neo,
                                         actor: "SERAPH",
                                         verification_report: report)
        report.update!(outcome: :escalated) if result.escalated?
        report_transition(initiative, result)
      end

      def returned?(report)
        report.verdicts.any? { |v| v.unmet? || v.inconclusive? }
      end

      def conforme(initiative, report)
        report.update!(outcome: :conforme)
        guide = TestGuide.create!(
          initiative: initiative, verification_report: report,
          code: "guia-pruebas-#{initiative.number}-#{@passes['seraph_verification']}")

        # Los ⊗ no llevan evidencia: llevan el paso que los cubre.
        report.verdicts.each_with_index do |verdict, index|
          step = GuideStep.create!(
            test_guide: guide, position: index + 1,
            title: verdict.dod_criterion.statement.truncate(60),
            evidence_origin: verdict.unsupported? ? :sole_evidence : :auto_verified,
            dod_criterion: verdict.dod_criterion)
          verdict.update!(guide_step: step) if verdict.unsupported?
        end

        say "  CONFORME · #{guide.code} · " \
            "#{guide.guide_steps.count(&:evidence_sole_evidence?)} de única evidencia"
        advance(initiative)
      end

      # ── Transiciones y utilidades ────────────────────────────────────────

      def published?(initiative)
        initiative.at_publication? && initiative.status_done?
      end

      def publish(initiative)
        Pipeline::Complete.call(
          initiative: initiative,
          summary: "#{initiative.artifacts.count} artefactos")
        say "● PUBLICADO · #{initiative.artifacts.count} artefactos en el bucket"
      end

      def advance(initiative)
        result = Pipeline::Advance.call(initiative: initiative)
        say "→ #{result.stage_entry.stage.upcase}"
      end

      def send_back(initiative, to:, actor:, human_note: nil)
        result = Pipeline::SendBack.call(initiative: initiative, to: to,
                                         actor: actor, human_note: human_note)
        report_transition(initiative, result)
      end

      def report_transition(initiative, result)
        initiative.reload

        if result.escalated?
          say "↺ DETENIDO · #{result.escalation.reason} · " \
              "iteration #{initiative.iteration} · " \
              "qa_cycles #{initiative.qa_cycles_consumed}"
        else
          say "↺ #{result.stage_entry.stage.upcase} · " \
              "iteration #{initiative.iteration} · " \
              "qa_cycles #{initiative.qa_cycles_consumed}"
        end
      end

      def human_note(initiative, body)
        HumanNote.create!(
          initiative: initiative, platform_client: @client,
          author_user: signer, body: body,
          code: "#{Date.current.iso8601}-#{SecureRandom.hex(2)}")
      end

      def latest_dod(initiative)
        initiative.definitions_of_done.latest_first.first
      end

      def signer = @signer ||= Platform::User.with_access.order(:platform_id).first!

      def say(line)
        @log << line
        @io&.puts(line)
      end
  end
end
