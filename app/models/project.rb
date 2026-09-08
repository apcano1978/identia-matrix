# El PROYECTO: la raíz del modelo y la frontera del invariante 10 (F11).
#
# Hasta F11 la raíz era `Platform::Client`, y eso ataba matrix a que todo su
# trabajo viniera de un cliente de identia-platform. El rediseño de septiembre
# añade proyectos PROPIOS —el primero es «matrix interna», con el que matrix pasa
# a desarrollarse a sí misma— y una proyección de solo lectura no puede sostener
# algo que matrix escribe.
#
#   Project
#    ├─ platform_client  → OPCIONAL
#    │     presente = proyecto DE CLIENTE · se sincroniza desde platform
#    │     ausente  = proyecto PROPIO     · vive solo en matrix
#    ├─ repositories
#    └─ initiatives
#
# **Lo que decide la naturaleza del proyecto es la presencia del cliente, no una
# columna de tipo.** Un enum podría discrepar de la realidad y habría que
# vigilarlo; una clave foránea nula no puede mentir.
#
# **La frontera se muda aquí.** El invariante 10 decía «ningún agente lee ni cita
# material de otro cliente» y pasa a decir «de otro proyecto». Es una frontera más
# ESTRECHA: dos clientes no comparten proyecto, así que todo lo que era legal lo
# sigue siendo, y además un proyecto de un cliente deja de ver el material de otro
# proyecto suyo. Eso es lo que hace segura la migración.
class Project < ApplicationRecord
  include FrozenSlug

  belongs_to :platform_client, class_name: "Platform::Client", optional: true

  # `restrict_with_exception` viaja desde `Platform::Client`, donde estaba antes
  # de F11. No se pierde por el camino: borrar un proyecto del que cuelga trabajo
  # dejaría artefactos publicados sin raíz, y sus claves ya están emitidas.
  has_many :repositories, dependent: :restrict_with_exception
  has_many :initiatives, dependent: :restrict_with_exception
  # La frontera desnormalizada del acta: el invariante 10 consulta por aquí.
  has_many :decisions, dependent: :restrict_with_exception
  # Los documentos SUBIDOS (F12). Los de platform llegan proyectados y cuelgan
  # del cliente, no del proyecto: son dos orígenes distintos que se citan igual.
  has_many :project_documents, dependent: :restrict_with_exception

  validates :name, presence: true
  # Kebab, el mismo formato que el slug de cliente: de ahí se hereda cuando el
  # proyecto nace de uno, y tiene que seguir casando con la gramática de citas.
  #
  # SIN TOPE DE LONGITUD, y es deliberado. El slug heredado puede ser tan largo
  # como la razón social del cliente —`Platform::Slug` usa `parameterize`, que no
  # trunca—, y acortarlo aquí rompería las claves que ya lo llevan dentro. El tope
  # de cuarenta que pide el rediseño es una regla del FORMULARIO DE ALTA, donde
  # alguien escribe un título; no de la raíz del modelo.
  validates :slug, presence: true, uniqueness: true,
                   format: { with: /\A[a-z0-9]+(?:-[a-z0-9]+)*\z/ }
  validates :opened_at, presence: true

  scope :own, -> { where(platform_client_id: nil) }
  scope :for_clients, -> { where.not(platform_client_id: nil) }

  # Se DERIVAN de la clave foránea, no se guardan. Ver la cabecera.
  def own? = platform_client_id.nil?
  def for_client? = !own?

  # La URL habla en slug, igual que la de cliente: `param: :slug` cambia el
  # nombre del segmento pero no lo que `project_path(project)` mete dentro.
  def to_param = slug

  def to_s = name
end
