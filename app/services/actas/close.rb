# Cerrar el acta y salir de la etapa 1 (F11 · B9).
#
# Cerrar el acta **es** salir de la etapa de necesidad: la etapa 1 termina cuando
# los requisitos están cerrados. Un solo acto para una sola intención, en vez de
# publicar por un lado y avanzar por otro.
#
# ── Se puede cerrar con decisiones abiertas ────────────────────────────────
#
# Y es deliberado. La maqueta pone al ARQUITECTO diciendo «no puedo cerrar el
# acta con ella pendiente», y la guía de la fase dice lo contrario: «una decisión
# abierta no impide avanzar, pero se arrastra». Manda la guía, porque ese
# arrastre —MORFEO las levanta como advertencia, LINK las recupera al cerrar— es
# el mecanismo entero, y bloquear el cierre lo dejaría sin un solo caso que lo
# estrene. El acta lo DICE al cerrar, en su resumen de etapa, en vez de impedirlo.
#
# ── Y no hay precondición nueva en `tank` ──────────────────────────────────
#
# Avanzar sin acta se sigue pudiendo: los evolutivos abiertos antes de F11 no
# tienen ninguna y nunca la tendrán, y `matrix:walk_pipeline` recorre las doce
# etapas sin pasar por aquí. Las dos paradas obligatorias del sistema siguen
# siendo dos.
class Actas::Close
  Refused = Class.new(StandardError)

  Result = Data.define(:artifact, :run, :open_count)

  def self.call(...) = new(...).call

  def initialize(initiative:, actor:)
    @initiative = initiative
    @actor = actor
  end

  def call
    validate!

    result = Agents::Run.call(initiative: initiative, agent: "arquitecto",
                              purpose: "requirements")
    advance!

    Result.new(artifact: result.artifact, run: result.agent_run,
               open_count: open_count)
  end

  private

  attr_reader :initiative, :actor

  def validate!
    # Sin esta guarda, cerrar dos veces publicaría un acta v2 en silencio:
    # `Artifacts::Publish#next_version_for` cuenta las que hay y sigue, que es lo
    # correcto para un artefacto que se corrige y no para uno que se cierra.
    if published_acta
      raise Refused, "el acta #{published_acta.code} ya está cerrada"
    end

    return if initiative.decisions.exists?

    raise Refused,
          "no hay ninguna decisión que cerrar: un acta vacía no dice nada que " \
          "la especificación pueda dar por cierto"
  end

  def published_acta
    @published_acta ||= initiative.artifacts.kind_acta.order(version: :desc).first
  end

  def open_count = initiative.decisions.pending.count

  # El resumen se escribe en la etapa que se CIERRA, no en la que se abre.
  #
  # `Pipeline::Advance` pasa su `summary` a `enter`, o sea a la etapa destino:
  # allí describe con qué llega TANK, no qué pasó en la necesidad. Y lo que hay
  # que dejar escrito aquí es lo segundo — con cuántas preguntas sin contestar se
  # decidió seguir, que es lo que alguien va a querer saber dentro de dos meses
  # mirando el nodo `necesidad` del pipeline.
  #
  # Escribir en la fila de etapa desde un servicio no es una excepción:
  # `Initiatives::Open#enter_need` ya la crea con su propio resumen.
  def advance!
    initiative.stage_entries.where(stage: :need, exited_at: nil)
              .update_all(summary: summary)

    Pipeline::Advance.call(initiative: initiative, actor: actor)
  end

  def summary
    cerradas = initiative.decisions.count - open_count
    resumen = "acta cerrada · #{cerradas} decididas"

    return resumen if open_count.zero?

    "#{resumen} · #{open_count} abiertas que se arrastran"
  end
end
