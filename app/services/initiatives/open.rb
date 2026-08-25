# Dar de alta un evolutivo (P1).
#
# **Un evolutivo no es una fila.** Son tres cosas, y las tres van en la misma
# transacción por la razón que `Pipeline::Transition` documenta para las suyas:
# si una se olvida, el síntoma es una tira de glifos que no cuadra con el
# historial, y eso se descubre tarde.
#
#   1. La fila, con el código que reparte el asignador.
#   2. Los enlaces a los repositorios que toca.
#   3. La entrada de etapa en `need` — sin ella `StageCache.derive` devuelve
#      nulo y el evolutivo no tiene ni etapa ni glifo.
#
# El caché se DERIVA de la entrada, no se escribe a mano: el caché solo es
# defendible mientras se pueda recomputar, y escribirlo aparte abre la puerta a
# que empiece a discrepar.
class Initiatives::Open
  Refused = Class.new(StandardError)

  def self.call(...) = new(...).call

  def initialize(client:, title:, repositories:, actor:, platform_project: nil)
    @client = client
    @title = title.to_s.strip
    @repositories = Array(repositories)
    @actor = actor
    @platform_project = platform_project
  end

  def call
    validate!

    Initiative.transaction do
      initiative = create_initiative
      link_repositories(initiative)
      enter_need(initiative)
      refresh_cache(initiative)
      record_event(initiative)

      initiative
    end
  end

  private

  attr_reader :client, :title, :repositories, :actor, :platform_project

  # **La frontera de cliente, comprobada aquí y no en la vista.** Un formulario
  # manipulado puede mandar el id del repositorio de otro cliente, y enlazarlo
  # metería material ajeno en el ámbito de un evolutivo — que es lo que el
  # invariante 10 existe para impedir.
  def validate!
    raise Refused, "hace falta un título" if title.blank?
    raise Refused, "hace falta al menos un repositorio" if repositories.empty?

    intrusos = repositories.reject { |repository| repository.platform_client_id == client.id }
    return if intrusos.empty?

    raise Refused, "esos repositorios no son de #{client.slug}: #{intrusos.map(&:name).join(', ')}"
  end

  def create_initiative
    Initiative.create!(
      platform_client: client,
      platform_project: platform_project,
      code: Matrix::Sequence.next_initiative_code,
      title: title,
      opened_at: Time.current)
  end

  def link_repositories(initiative)
    repositories.each do |repository|
      initiative.initiative_repositories.create!(
        repository: repository, first_linked_at: Time.current)
    end
  end

  # `active` y no `pending`: el evolutivo está en `need` desde que se abre, y la
  # necesidad la escribió quien lo dio de alta. Lo que espera es a TANK, que
  # llega en F9.
  def enter_need(initiative)
    initiative.stage_entries.create!(
      stage: :need, iteration: 1, qa_cycle: 0, status: :active,
      entered_at: initiative.opened_at,
      summary: "Alta manual · #{actor}")
  end

  def refresh_cache(initiative)
    stage, status = StageCache.derive(initiative)
    initiative.update!(current_stage: stage, current_stage_status: status,
                       stage_changed_at: initiative.opened_at)
  end

  def record_event(initiative)
    Event.create!(
      occurred_at: Time.current, actor: actor, kind: "initiative_opened",
      initiative: initiative, platform_client: client,
      message: "#{initiative.code} · alta · #{repositories.map(&:name).join(', ')}",
      payload: { repositories: repositories.map(&:name),
                 platform_project_ref: platform_project&.platform_project_ref })
  end
end
