# Cierra la duodécima etapa. Es el único sitio desde el que un evolutivo puede
# quedar `publication/done`.
#
# Hacía falta un servicio propio: `Advance` cierra la etapa que deja al entrar
# en la siguiente, y de `publication` no se sale. Sin esto, el estado terminal
# que el seed pinta en ev-002 y ev-009 no lo podía alcanzar nada — el sistema
# sabía llegar al final pero no cerrarlo.
class Pipeline::Complete
  include Pipeline::Transition

  Result = Data.define(:initiative, :stage_entry)

  def self.call(...) = new(...).call

  def initialize(initiative:, actor: Pipeline::SYSTEM_ACTOR, summary: nil)
    @initiative = initiative
    @actor = actor
    @summary = summary
  end

  def call
    unless initiative.at_publication?
      raise Pipeline::InvalidTransition,
            "#{initiative.code} no está en publication: está en " \
            "#{initiative.current_stage}"
    end

    initiative.with_lock do
      entry = current_entry
      entry.update!(status: :done, exited_at: Time.current,
                    summary: @summary || entry.summary)
      initiative.update!(current_stage_status: :done)
      record_event(kind: "published",
                   message: "PUBLICATION · artefactos en el bucket",
                   iteration: initiative.iteration)

      Result.new(initiative: initiative, stage_entry: entry)
    end
  end
end
