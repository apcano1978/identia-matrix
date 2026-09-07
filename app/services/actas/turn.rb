# Un turno de la conversación con el ARQUITECTO (F11 · B9).
#
# **Es lo primero que matrix hace de forma síncrona.** Los seis agentes de
# siempre son un job de Sidekiq: se lanzan, tardan y publican. Aquí hay ida y
# vuelta con una persona, y esperar a una cola entre pregunta y respuesta haría
# la entrevista inservible.
#
# La pieza ya era síncrona —`Agents::Run.call` ejecuta y devuelve—; lo asíncrono
# es `Agents::RunJob`, que la envuelve. Este servicio **no lo usa**: llama a
# `Agents::Run` dentro de la petición y no encola nada.
#
# ── Dónde vive lo que escribe la persona ───────────────────────────────────
#
# En `human_notes`, y no en una tabla de chat. La nota es de nivel ORIGEN y es
# **citable** —`[src:note/2026-09-07-ap]`—, que es exactamente lo que hace falta:
# lo que alguien decide en una entrevista de requisitos ES un origen, y la
# respuesta de una decisión tiene que poder señalar quién la dio.
#
# Y viaja sola: `MATERIAL["arquitecto"]` ya incluye `human_notes`, así que el
# agente recibe la conversación entera sin enmendar el contrato.
#
# La otra mitad del diálogo no se persiste como prosa **porque no es prosa**: la
# respuesta del ARQUITECTO es la lista de decisiones, y esa sí está en su tabla.
class Actas::Turn
  Refused = Class.new(StandardError)

  Result = Data.define(:note, :run, :decisions)

  def self.call(...) = new(...).call

  def initialize(initiative:, message:, author:)
    @initiative = initiative
    @message = message.to_s.strip
    @author = author
  end

  def call
    validate!

    note = write_note
    result = run_the_interview

    Result.new(note: note, run: result.agent_run,
               decisions: apply(result))
  end

  private

  attr_reader :initiative, :message, :author

  # La misma raya que `Decision` y `Decisions::Apply`: publicada el acta, de ella
  # salen la spec y los deltas, y lo que cambie a partir de ahí es otro delta.
  # Se comprueba aquí también para no dejar escrita una nota de una conversación
  # que no puede continuar.
  def validate!
    raise Refused, "no hay nada escrito" if message.blank?

    acta = initiative.artifacts.kind_acta.order(version: :desc).first
    return if acta.blank?

    raise Refused,
          "el acta #{acta.code} ya está cerrada: lo que cambie a partir de aquí " \
          "es otro delta, no un turno más de esta conversación"
  end

  def write_note
    HumanNote.create!(
      initiative: initiative, project: initiative.project, author_user: author,
      code: HumanNote.code_for(author, project: initiative.project),
      body: message)
  end

  # ⚠ `Agents::Run` y NO `Agents::RunJob`. Un turno encolado no es un turno.
  #
  # El `ensure` marca la fila como fallida si algo revienta a mitad: no sustituye
  # a que el índice único deje pasar los turnos —un proceso que muere no ejecuta
  # ningún `ensure`— pero evita dejar un `running` colgado en el caso normal.
  def run_the_interview
    Agents::Run.call(initiative: initiative, agent: "arquitecto",
                     purpose: "interview")
  rescue StandardError => error
    mark_failed(error)
    raise
  end

  def mark_failed(error)
    initiative.agent_runs.live.where(agent: :arquitecto, purpose: :interview)
              .update_all(status: AgentRun.statuses[:failed],
                          finished_at: Time.current,
                          error: error.message.truncate(1000))
  end

  def apply(result)
    Decisions::Apply.call(initiative: initiative, run: result.agent_run,
                          findings: result.result.findings)
  end
end
