# Lo que el dashboard y la barra de título necesitan saber del conjunto.
#
# Vive aquí y no como cinco scopes en `Initiative` porque las condiciones son
# sutiles —«ciclo QA» es *tiene ciclos consumidos, sigue vivo, no está en una
# puerta y no está detenido*— y repartidas por el modelo se desincronizan de la
# pantalla que las enseña. Que se lean juntas es lo que las mantiene coherentes.
class Dashboard::Board
  GATES = %w[gate_1 gate_2].freeze

  # Las cinco bandejas, ORDENADAS POR LO QUE LE PIDEN AL HUMANO. Ese orden es el
  # contenido de la pantalla: lo primero es lo que está bloqueado esperándote, y
  # lo último, aquello de lo que no tienes que ocuparte.
  #
  # `ESPERAN APROBACIÓN` recoge TODA escalada abierta y no solo los pasos
  # irrecorribles, que es lo que pedía la guía. La maqueta deja fuera a ev-024
  # —detenido por entorno— y lo cuenta como ciclo QA, contradiciendo su propio
  # texto: «el flujo queda escalado a decisión humana». Desde el lado de la
  # persona, los cuatro motivos de escalada son lo mismo.
  TRAYS = [
    { key: :awaiting_signature, title: "ESPERAN FIRMA", tone: :gold,
      gloss: "gate 1 · autoriza la ejecución", action: "firmar" },
    { key: :awaiting_validation, title: "ESPERAN VALIDACIÓN", tone: :gate2,
      gloss: "gate 2 · confirma que lo ejecutado sirve", action: "validar" },
    { key: :halted, title: "ESPERAN APROBACIÓN", tone: :fail,
      gloss: "el flujo espera una decisión humana", action: "revisar" },
    { key: :qa_cycle, title: "CICLO QA", tone: :fail,
      gloss: "seraph verificó contra el DoD", action: "abrir" },
    { key: :in_progress, title: "EN CURSO", tone: :muted,
      gloss: "sin acción humana requerida", action: "abrir" }
  ].freeze

  Summary = Data.define(:active, :in_progress, :qa_cycle, :awaiting_human)
  Tray = Data.define(:key, :title, :tone, :gloss, :action, :rows) do
    def count = rows.size
  end
  Row = Data.define(:initiative, :headline, :sources, :action)

  attr_reader :filter

  def initialize(scope = Initiative.all, filter: nil)
    @scope = scope
    @filter = Dashboard::Filter.new(filter)
  end

  def summary
    Summary.new(active: open.size, in_progress: in_progress.size,
                qa_cycle: qa_cycle.size, awaiting_human: awaiting_human.size)
  end

  # Las bandejas ya filtradas y con sus filas compuestas. El filtro se aplica
  # AQUÍ y no dentro de cada bandeja: así el resumen de la barra de título sigue
  # contando el total mientras la pantalla enseña el subconjunto.
  def trays
    TRAYS.filter_map do |definition|
      rows = visible(public_send(definition[:key]))
             .map { |initiative| row_for(initiative, definition[:action]) }
      next if rows.empty?

      Tray.new(**definition, rows: rows)
    end
  end

  def visible_count = trays.sum(&:count)

  # Los evolutivos que esperan a una persona: los dos que están en una puerta y
  # los que están detenidos. La condición vive en `Initiative#awaiting_human?`
  # porque la preguntan tres pantallas; aquí solo se reparte en bandejas.
  def awaiting_human = awaiting_signature + awaiting_validation + halted

  def awaiting_signature = ordered(open.select(&:at_gate_1?))
  def awaiting_validation = ordered(open.select(&:at_gate_2?))
  def halted = ordered(open.select { |i| i.open_escalation.present? })

  def qa_cycle
    ordered(open.select do |initiative|
      initiative.qa_cycles_consumed.positive? &&
        initiative.open_escalation.blank? &&
        GATES.exclude?(initiative.current_stage)
    end)
  end

  # Lo que queda: un agente está trabajando y nadie tiene que hacer nada.
  def in_progress = ordered(open - awaiting_human - qa_cycle)

  private
    attr_reader :scope

    def open
      @open ||= scope.open
                     .includes(:platform_client, :stage_entries, :escalations,
                               :work_packages, :test_guides,
                               :verification_reports,
                               initiative_repositories: :repository)
                     .to_a
    end

    def visible(initiatives)
      initiatives.select { |initiative| filter.matches?(initiative, board: self) }
    end

    # Lo más antiguo primero: una espera larga es lo que hay que atender antes.
    def ordered(initiatives)
      initiatives.sort_by { |i| i.stage_changed_at || i.opened_at }
    end

    def row_for(initiative, action)
      Row.new(initiative: initiative, action: action,
              headline: headline_for(initiative),
              sources: sources_for(initiative))
    end

    # Lo que la fila dice de sí misma depende de qué la tiene parada: quien
    # espera una firma quiere saber qué firma, y quien mira un ciclo de QA quiere
    # saber cuántos criterios fallaron. Un texto único para las cinco bandejas
    # sería el mismo dato repetido cinco veces.
    def headline_for(initiative)
      case initiative.current_stage
      when "gate_1" then package_headline(initiative)
      when "gate_2" then guide_headline(initiative)
      else
        escalation_headline(initiative) || verification_headline(initiative) ||
          current_summary(initiative)
      end
    end

    def escalation_headline(initiative)
      reason = initiative.open_escalation&.reason
      return nil if reason.blank?

      "⊘ #{reason.tr('_', ' ')}"
    end

    def package_headline(initiative)
      package = initiative.work_packages.select(&:sealed?).max_by(&:sealed_at)
      return current_summary(initiative) if package.blank?

      counts = [ "#{package.tasks_count} tareas" ]
      if package.migrations_count.positive?
        counts << "#{package.migrations_count} migraciones"
      end

      "#{package.code} · #{counts.join(' · ')}"
    end

    def guide_headline(initiative)
      guide = initiative.test_guides.max_by(&:id)
      return current_summary(initiative) if guide.blank?

      coverage = guide.coverage
      "#{guide.code} · #{coverage[:walked]}/#{coverage[:total]} pasos"
    end

    def verification_headline(initiative)
      return nil unless initiative.qa_cycles_consumed.positive?

      report = initiative.verification_reports.max_by(&:id)
      return nil if report.blank?

      counts = report.verdict_counts
      glyphs = Verdict::GLYPHS.filter_map do |result, glyph|
        "#{glyph}#{counts[result]}" if counts[result].to_i.positive?
      end

      "#{report.code} · #{glyphs.join(' ')}"
    end

    def current_summary(initiative)
      initiative.stage_entries
                .select { |entry| entry.stage == initiative.current_stage }
                .max_by(&:iteration)&.summary.presence || "—"
    end

    # `caser/triaje-core @a02f781`. El sha es el ANCLADO: es sobre ese estado del
    # código que habla todo lo que el evolutivo cite.
    def sources_for(initiative)
      slug = initiative.platform_client.slug

      initiative.initiative_repositories.map do |link|
        [ "#{slug}/#{link.repository.name}", link.pinned_sha ].compact.join(" @")
      end
    end
end
