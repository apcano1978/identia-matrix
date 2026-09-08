# Un documento subido a un proyecto. Fuente de ORIGEN, igual que uno de platform.
#
# Se cita igual —`[src:doc/acta-precios#p2]`— y pesa igual: un acta subida a mano
# y la misma acta llegada de platform tienen el mismo valor probatorio. Lo que
# cambia es **quién responde de ella**, y eso se ve en la ficha, no en la cita.
class ProjectDocument < ApplicationRecord
  # El slug se elige una vez y no se mueve: va dentro de citas escritas en
  # markdown que nadie puede reescribir. Es la misma regla que en `Project` e
  # `Initiative`, y por eso el concern existe.
  include FrozenSlug

  belongs_to :project
  belongs_to :uploaded_by_user, class_name: "Platform::User"

  # ⚠ EN SU PROPIO ALMACÉN, y no es higiene de configuración.
  #
  # `Artifacts::Verify#orphans` enumera el almacén de artefactos y llama huérfano
  # a todo objeto que no reclame un `Artifact`. Puede permitírselo porque ahí no
  # se guarda otra cosa; un documento en el mismo sitio dejaría
  # `matrix:verify_artifacts` en rojo para siempre. El porqué entero, con las dos
  # trampas —el bucket y la raíz anidada—, está en `config/storage.yml`.
  has_one_attached :file, service: :documents

  # Se acota a un evolutivo igual que uno de platform: el ámbito es un filtro,
  # nunca una copia.
  has_many :initiative_sources, as: :source, dependent: :destroy
  has_many :citations, as: :target, dependent: :nullify

  validates :slug, presence: true,
                   uniqueness: { scope: :project_id },
                   format: { with: /\A[a-z0-9]+(?:-[a-z0-9]+)*\z/ }
  validates :title, presence: true

  # Los que entran en el ámbito de un evolutivo NUEVO. Un retirado no aparece
  # aquí y sigue existiendo, que es toda la diferencia entre retirar y borrar.
  scope :available, -> { where(retired_at: nil) }
  scope :retired, -> { where.not(retired_at: nil) }

  # ⚠ NO mira `retired_at`, y es deliberado.
  #
  # Retirar saca el documento del ámbito de los evolutivos nuevos —eso es
  # `available`— pero **una cita ya emitida contra él sigue resolviendo**. Si
  # `citable?` cayera al retirarlo, un artefacto publicado hace tres meses
  # pasaría a citar algo que el sistema dice que no se puede citar, y nadie
  # podría reescribirlo.
  #
  # Un documento sin cuerpo no es citable por ancla, y quien lo cite tiene que
  # saberlo antes de intentarlo. Misma regla que `Platform::Document#citable?`.
  def citable? = body.present?

  def retired? = retired_at.present?

  # Lo que hace falta para leer el cuerpo, cuando el cuerpo existe.
  def extracted? = extracted_at.present?

  def citation = "[src:doc/#{slug}]"

  def to_s = title

  # El nombre con el que se cita, libre DENTRO DEL PROYECTO y también entre los
  # documentos de platform de su cliente.
  #
  # Las dos tablas y no solo la suya: la cita `[src:doc/<slug>]` no dice de dónde
  # viene el documento, y `Citations::Resolve` la resuelve dentro del proyecto.
  # Si los dos pudieran llamarse igual, tendría que elegir en silencio entre
  # ellos — dentro de una cita que ya está escrita.
  #
  # La otra dirección la cubre `Platform::Projection#assign_slug`: una
  # sincronización posterior tampoco puede crear la ambigüedad que esto evita.
  def self.slug_for(title, project:, fallback: "documento")
    Platform::Slug.derive(
      self, title,
      fallback: fallback,
      scope: { project_id: project.id },
      among: [ Platform::Document.where(platform_client_id: project.platform_client_id) ])
  end
end
