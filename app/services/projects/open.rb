# Dar de alta un proyecto PROPIO (F11 · B7b).
#
# **Propio y solo propio, y no es una limitación provisional.** El proyecto de un
# cliente lo crea `Platform::Sync#ensure_projects` y lo borra
# `matrix:prune_projection`: nace con él y muere con él. Crearlo también desde
# aquí abriría un segundo camino para lo mismo, y crear en un sitio y borrar en
# otro es exactamente como se desincronizan las cosas.
#
# Lo que decide la naturaleza del proyecto es la ausencia de cliente, no una
# columna de tipo — ver la cabecera de `Project`—, así que este servicio no
# necesita decir «propio» en ningún sitio: le basta con no poner ninguno.
class Projects::Open
  Refused = Class.new(StandardError)

  # El tope que la guía de la fase pide y que NO cabe en el modelo: el slug de un
  # proyecto de cliente se hereda de la razón social y `parameterize` no trunca,
  # así que validarlo en `Project` habría reventado el backfill contra datos
  # reales. Es una regla de ESTE formulario, donde alguien escribe un nombre
  # corto a mano, y por eso vive aquí.
  MAX_SLUG = 40

  def self.call(...) = new(...).call

  def initialize(slug:, name:, actor:)
    @slug = slug.to_s.strip.downcase
    @name = name.to_s.strip
    @actor = actor
  end

  def call
    validate!

    Project.transaction do
      project = Project.create!(slug: slug, name: name, opened_at: Time.current)
      record_event(project)

      project
    end
  end

  private

  attr_reader :slug, :name, :actor

  # Lo que es del formulario se comprueba aquí para poder decirlo con palabras.
  # La unicidad NO: esa la defiende el índice de la tabla, que es el único sitio
  # donde dos peticiones simultáneas no pueden colarse entre la comprobación y
  # la escritura. El controlador traduce su excepción.
  def validate!
    raise Refused, "hace falta un nombre corto" if slug.blank?
    raise Refused, "hace falta un título" if name.blank?

    unless slug.match?(/\A[a-z0-9]+(?:-[a-z0-9]+)*\z/)
      raise Refused, "el nombre corto va en minúsculas, con guiones y sin acentos " \
                     "—#{slug.inspect} no vale—: entra en las claves de artefacto"
    end

    return if slug.length <= MAX_SLUG

    raise Refused, "el nombre corto no puede pasar de #{MAX_SLUG} caracteres, " \
                   "y #{slug.inspect} tiene #{slug.length}"
  end

  # Sin `platform_client`: es la única forma que tiene un evento de decir que
  # esto no es de nadie de fuera. El invariante de las dos fronteras lo admite —
  # exige que no se contradigan, no que estén las dos.
  def record_event(project)
    Event.create!(
      occurred_at: Time.current, actor: actor, kind: "project_opened",
      project: project,
      message: "#{project.slug} · alta · proyecto propio",
      payload: { name: project.name })
  end
end
