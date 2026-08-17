# Las pantallas de la cadena de evidencia (F6).
module GatesHelper
  # Los cuatro veredictos, SIEMPRE los cuatro y en el mismo orden.
  #
  # No son «dos buenos y dos malos»: son cuatro resultados distintos, y la
  # pantalla tiene que enseñarlos como cuatro. Un contador a cero también dice
  # algo — que nada falló— y esconderlo lo convertiría en una ausencia.
  VERDICTS = %w[met unmet inconclusive unsupported].freeze

  VERDICT_LABELS = {
    "met" => "cumplidos",
    "unmet" => "incumplidos",
    "inconclusive" => "no concluyentes",
    "unsupported" => "no soportado aún"
  }.freeze

  VERDICT_TONES = {
    "met" => "text-glyph-done",
    "unmet" => "text-glyph-fail",
    "inconclusive" => "text-glyph-active",
    "unsupported" => "text-glyph-unsupported"
  }.freeze

  def verdict_label(result) = VERDICT_LABELS.fetch(result.to_s)
  def verdict_tone(result) = VERDICT_TONES.fetch(result.to_s)

  # `{ "met" => 9, "unsupported" => 2 }` completado a los cuatro.
  def verdict_tally(report)
    counts = report&.verdict_counts || {}

    VERDICTS.index_with { |result| counts[result].to_i }
  end

  # De qué repositorio responde un criterio. Sin repositorio no es un descuido:
  # es un criterio ENTRE SERVICIOS, y es justo el que acaba en ⊗ porque ningún
  # CI levanta dos servicios a la vez para que se hablen.
  def criterion_scope(criterion)
    criterion.repository&.name || "entre servicios"
  end

  # Los criterios agrupados por aquello de lo que responden, para el panel.
  def criteria_by_scope(criteria)
    criteria.group_by { |criterion| criterion_scope(criterion) }
            .sort_by { |scope, _| scope == "entre servicios" ? "zzz" : scope }
  end

  # La cobertura de evidencia, con sus TRES estados. El tercero apareció con el
  # ⊗ irrecorrible: hay pasos que nadie recorrió y que alguien, con nombre,
  # autorizó cerrar así. Meterlos en «recorrido» falsearía la única cifra que
  # GATE 2 existe para dar.
  COVERAGE_STATES = {
    walked: [ "✓", "recorrido", "text-glyph-done" ],
    exempted: [ "⊘", "eximido", "text-glyph-fail" ],
    pending: [ "○", "pendiente", "text-glyph-pending" ]
  }.freeze

  def step_state(step)
    return :walked if step.walked?
    return :exempted if step.exempted?

    :pending
  end

  def step_state_glyph(step) = COVERAGE_STATES.fetch(step_state(step)).first
  def step_state_label(step) = COVERAGE_STATES.fetch(step_state(step))[1]
  def step_state_tone(step) = COVERAGE_STATES.fetch(step_state(step)).last

  # El estado de un check de CI, con su recuento. El semáforo se compone de
  # TODOS los checks obligatorios —lint y análisis de seguridad incluidos—, no
  # solo de la suite: un rubocop en rojo con los tests en verde sigue siendo un
  # desarrollo que va a explotar.
  def ci_summary(check)
    parts = []
    parts << pluralize(check.checks_passed, "check") if check.checks_passed.to_i.positive?
    parts << "#{check.duration_seconds}s" if check.duration_seconds
    parts << "#{check.tests_total} tests" if check.tests_total

    parts.join(" · ")
  end
end
