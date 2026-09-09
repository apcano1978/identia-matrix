# Dar de alta un evolutivo (P1).
#
# **Un evolutivo no es una fila.** Son tres cosas, y las tres van en la misma
# transacción por la razón que `Pipeline::Transition` documenta para las suyas:
# si una se olvida, el síntoma es una tira de glifos que no cuadra con el
# historial, y eso se descubre tarde.
#
#   1. La fila, con el código que reparte el asignador.
#   2. Los enlaces a los repositorios que toca.
#   3. El ámbito documental, si es que se recortó (F12 · B5).
#   4. La entrada de etapa en `need` — sin ella `StageCache.derive` devuelve
#      nulo y el evolutivo no tiene ni etapa ni glifo.
#
# El caché se DERIVA de la entrada, no se escribe a mano: el caché solo es
# defendible mientras se pueda recomputar, y escribirlo aparte abre la puerta a
# que empiece a discrepar.
class Initiatives::Open
  Refused = Class.new(StandardError)

  def self.call(...) = new(...).call

  # `sources:` es OPCIONAL y `nil` no es lo mismo que `[]`.
  #
  #   nil  →  quien llama no habla de ámbito: no se recorta nada
  #   []   →  se marcaron cero fuentes, y eso es una decisión: cero fuentes
  #
  # La diferencia importa porque `Array(nil)` es `[]`, y confundirlas dejaría a
  # cada evolutivo abierto por código —el seed, los tests, `matrix:walk_pipeline`—
  # sin una sola fuente.
  #
  # `attached:` son los documentos que se acaban de SUBIR en el mismo formulario,
  # y van aparte de lo marcado por una razón concreta: **adjuntar no es
  # recortar**. Nadie pudo marcar una casilla que no existía cuando envió, así
  # que contarlos como elección dejaría el ámbito sellado por el simple hecho de
  # arrastrar un fichero. Entran siempre en el ámbito —y si no se recortó, entran
  # solos, porque lo que no está sellado hereda todo lo disponible—.
  def initialize(project:, title:, repositories:, actor:, platform_project: nil,
                 sources: nil, attached: [])
    @project = project
    @title = title.to_s.strip
    @repositories = Array(repositories)
    @actor = actor
    @platform_project = platform_project
    @sources = sources
    @attached = Array(attached)
  end

  def call
    validate!

    Initiative.transaction do
      initiative = create_initiative
      link_repositories(initiative)
      scope_sources(initiative)
      enter_need(initiative)
      refresh_cache(initiative)
      record_event(initiative)

      initiative
    end
  end

  private

  attr_reader :project, :title, :repositories, :actor, :platform_project, :sources,
              :attached


  # **La frontera de proyecto, comprobada aquí y no en la vista.** Un formulario
  # manipulado puede mandar el id del repositorio de otro proyecto, y enlazarlo
  # metería material ajeno en el ámbito de un evolutivo — que es lo que el
  # invariante 10 existe para impedir.
  def validate!
    raise Refused, "hace falta un título" if title.blank?
    raise Refused, "hace falta al menos un repositorio" if repositories.empty?

    intrusos = repositories.reject { |repository| repository.project_id == project&.id }
    unless intrusos.empty?
      raise Refused, "esos repositorios no son de #{project&.slug}: " \
                     "#{intrusos.map(&:name).join(', ')}"
    end

    validate_sources!
  end

  # La misma comprobación, del lado documental. Aquí no basta con mirar una
  # columna: un documento de platform pertenece al CLIENTE y uno subido al
  # PROYECTO, así que la frontera de cada tipo es distinta. Lo que sí es una
  # lista cerrada es `available_for`, y comparar contra ella responde por los
  # tres tipos a la vez sin repetir la asimetría.
  def validate_sources!
    return if sources.nil?

    intrusos = (sources + attached) - available
    return if intrusos.empty?

    raise Refused, "esas fuentes no son de #{project&.slug}: " \
                   "#{intrusos.map(&:slug).join(', ')}"
  end

  def create_initiative
    code = Matrix::Sequence.next_initiative_code

    Initiative.create!(
      project: project,
      platform_project: platform_project,
      code: code,
      slug: slug_for(code),
      title: title,
      opened_at: Time.current)
  end

  # El NOMBRE, derivado del título y acotado al proyecto.
  #
  # Se congela al crear —va dentro de las claves de los artefactos que este
  # evolutivo produzca— así que esta es la única oportunidad de elegirlo. El
  # formulario de alta lo enseñará y dejará editarlo en F11 · B7; hasta entonces
  # se deriva y ya.
  #
  # El respaldo es el CÓDIGO, y es un respaldo bueno: `ev-031` es un slug válido,
  # así que un título del que `parameterize` no saque nada aprovechable —«···»—
  # deja un evolutivo con nombre utilizable en vez de una fila sin slug.
  def slug_for(code)
    Platform::Slug.derive(Initiative, title, fallback: code,
                                             scope: { project_id: project&.id })
  end

  def link_repositories(initiative)
    repositories.each do |repository|
      initiative.initiative_repositories.create!(
        repository: repository, first_linked_at: Time.current)
    end
  end

  # ⚠ EL ÁMBITO DOCUMENTAL, y la regla entera de cuándo se recorta (F12 · B5).
  #
  # **Se sella si lo marcado ≠ lo citable disponible.** Dicho al revés, que es
  # como se lee en la pantalla: dejar el marcado por defecto no escribe ni una
  # fila, y quien no recorta sigue heredando lo que se suba mañana.
  #
  # Vive aquí y no en el controlador porque es una regla de dominio: se puede
  # probar sin pantalla, y el día que haya otra forma de abrir un evolutivo
  # seguirá valiendo.
  #
  # Recortar es DEJAR FUERA algo que podía entrar, y quien lo dice es
  # `Sources::Scope.narrowed?` — ahí está el porqué de que sea una resta.
  #
  # Se comparan LAS CASILLAS QUE HABÍA, sin lo recién adjuntado: `available` se
  # calcula después de subir, así que incluye lo nuevo, y contarlo sellaría el
  # ámbito de quien solo arrastró un fichero.
  def scope_sources(initiative)
    return if sources.nil?
    return unless Sources::Scope.narrowed?(sources, offered)

    (sources + attached).uniq.each do |source|
      initiative.initiative_sources.create!(source: source)
    end
    initiative.update!(sources_scoped_at: Time.current)
  end

  # Lo que el formulario ofreció marcado: lo citable que ya existía. El criterio
  # vive en `Sources::Scope` porque lo comparte con `Sources::Rescope`, que es el
  # otro sitio desde el que se decide un ámbito.
  def offered = Sources::Scope.offered(project) - attached

  # Lo que este proyecto puede ofrecer, hoy. Se calcula una vez: lo miran la
  # validación y el sellado, y entre las dos no puede cambiar.
  def available
    @available ||= Sources::Scope.available_for(project).values.flat_map(&:sources)
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
      initiative: initiative, platform_client: project.platform_client, project: project,
      message: "#{initiative.code} · alta · #{repositories.map(&:name).join(', ')}" \
               "#{scope_note(initiative)}",
      payload: { repositories: repositories.map(&:name),
                 sources_scoped: initiative.sources_scoped?,
                 sources: initiative.initiative_sources.count,
                 platform_project_ref: platform_project&.platform_project_ref })
  end

  # Recortar deja constancia; no recortar no dice nada, porque no pasó nada.
  def scope_note(initiative)
    return "" unless initiative.sources_scoped?

    " · ámbito recortado a #{initiative.initiative_sources.count} fuentes"
  end
end
