# El eje de MEMORIA. Un repositorio de código: acumula los evolutivos que lo han
# tocado, sus ADR y su historia. No tiene pipeline ni estado — eso es del otro
# eje, y confundirlos es el error del que nace la mitad del diseño de F2.
#
# La palabra «repositorio» significa siempre esto, nunca un proyecto de
# platform ni un evolutivo.
class Repository < ApplicationRecord
  belongs_to :project

  # El cliente ya no es una columna: se responde A TRAVÉS DEL PROYECTO, que es
  # donde vive. La frase «el cliente de un repositorio» sigue siendo verdad; lo que cambió es
  # por dónde se llega.
  #
  # ⚠ NUNCA en un `where`. La frontera se impone con una clave foránea, no
  # navegando asociaciones —es el invariante 10— y una consulta que lo intentara
  # fallaría con la columna ausente, que es ruidoso y está bien.
  #
  # Un proyecto PROPIO devuelve `nil`: no tiene cliente detrás.
  # Se delegan LOS DOS: el id sale de una columna de `projects`, así que
  # `platform_client_id` no carga al cliente, solo lo nombra. Lo usan las
  # escrituras de `events`, que sí conserva la columna.
  delegate :platform_client, :platform_client_id, to: :project

  has_many :initiative_repositories, dependent: :destroy
  has_many :initiatives, through: :initiative_repositories
  has_many :adrs, dependent: :destroy
  has_many :citations, dependent: :nullify
  has_many :ci_checks, dependent: :destroy
  has_many :work_package_repositories, dependent: :destroy

  validates :name, presence: true,
                   uniqueness: { scope: :project_id },
                   format: { with: /\A[a-z0-9]+(?:[-_.][a-z0-9]+)*\z/ }
  validates :default_branch, presence: true

  # Nulo significa «este repositorio no admite verificación automática», y así
  # se dice en su ficha en vez de fingir que verifica. Lo consulta SERAPH (F10).
  def ci_configured? = ci_provider.present? && ci_repo_slug.present?

  def to_param = name

  def to_s = name
end
