# Convertir los hallazgos de una ejecución del ARQUITECTO en filas del acta.
#
# Es el único sitio donde nace una decisión, y por eso es donde vive la regla del
# ordinal. Un hallazgo con `reference` actualiza la decisión que ese número
# nombra; uno sin `reference` es nueva y se lleva el siguiente ordinal libre.
#
# ── Por qué RECONCILIA en vez de reemplazar ────────────────────────────────
#
# La salida fácil sería borrar las decisiones del evolutivo y reescribirlas con
# lo que devuelva el turno. Eso renumeraría todo en cuanto el agente omitiera
# una, y el ordinal está dentro de citas ya emitidas: `#abierta-4` pasaría a
# señalar otra pregunta sin que nada avisara.
#
# Reconciliar cuesta este fichero y a cambio el ordinal es estable por
# construcción, no por disciplina de quien escriba el prompt.
class Decisions::Apply
  Refused = Class.new(StandardError)

  KIND = "decision".freeze

  def self.call(...) = new(...).call

  def initialize(initiative:, findings:, run: nil)
    @initiative = initiative
    @findings = Array(findings).select { |f| f["kind"].to_s == KIND }
    @run = run
  end

  def call
    return [] if findings.empty?

    refuse_if_published!

    Decision.transaction do
      findings.map { |finding| apply(finding) }
    end
  end

  private

  attr_reader :initiative, :findings, :run

  # La misma raya que `Decision#refuse_change_after_publication`, comprobada
  # antes de empezar: sin esto el primer hallazgo nuevo se crearía —crear no pasa
  # por la guarda de `before_update`— y el primero que actualizara reventaría a
  # mitad de la tanda.
  def refuse_if_published!
    acta = initiative.artifacts.kind_acta.order(version: :desc).first
    return if acta.blank?

    raise Refused,
          "el acta #{acta.code} ya está publicada: de ella salen la spec y los " \
          "deltas, así que lo que cambie a partir de aquí es otro delta"
  end

  def apply(finding)
    decision = existing(finding) || build_next

    decision.assign_attributes(
      question: finding["statement"].to_s.strip,
      answer: finding["answer"].presence,
      status: finding["status"].presence || "open",
      source_citation: finding["evidence"].presence,
      raised_by_run: decision.raised_by_run || run)
    decision.save!
    decision
  end

  # Por ORDINAL y dentro del evolutivo. El agente devuelve el número porque es lo
  # que recibió en `config.decisions`; identificar por el texto de la pregunta
  # habría hecho que reformularla creara una decisión nueva.
  def existing(finding)
    reference = finding["reference"].presence
    return nil if reference.blank?

    ordinal = Integer(reference, exception: false)
    raise Refused, "referencia de decisión que no es un ordinal: #{reference.inspect}" if ordinal.nil?

    initiative.decisions.find_by(ordinal: ordinal) ||
      raise(Refused, "no hay ninguna decisión #{ordinal} en #{initiative.code}")
  end

  # `max + 1` y no una secuencia como la de los códigos de evolutivo: aquella
  # existe porque un número liberado por un borrado se reciclaría, y aquí no se
  # borra ninguna fila — la única baja posible es el `dependent: :destroy` del
  # evolutivo entero, que se las lleva todas. El índice único
  # `(initiative_id, ordinal)` cubre la carrera entre dos turnos simultáneos.
  def build_next
    siguiente = initiative.decisions.maximum(:ordinal).to_i + 1

    initiative.decisions.new(project_id: initiative.project_id, ordinal: siguiente)
  end
end
