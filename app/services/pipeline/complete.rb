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
                    summary: @summary || entry.summary || prefix)
      initiative.update!(current_stage_status: :done)
      record_event(kind: "published",
                   message: "PUBLICATION · artefactos en #{prefix}",
                   iteration: initiative.iteration)

      Result.new(initiative: initiative, stage_entry: entry)
    end
  end

  private
    # La raíz del evolutivo en el bucket: `artifacts://vivla/ev-009`.
    #
    # Hasta F5 la etapa 12 era un nodo que no hacía nada. Dejar constancia de
    # dónde quedó publicado es lo mínimo que puede hacer la última etapa del
    # pipeline, y es lo que la maqueta enseña en el nodo 12 de ev-009 y ev-002.
    # `Artifacts::Key.prefix_for` existía desde F0 sin que lo usara nadie.
    def prefix
      Artifacts::Key.prefix_for(client: initiative.platform_client.slug,
                                initiative: initiative.code)
    end
end
