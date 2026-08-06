# El cliente. Es la frontera dura del sistema: ningún agente lee ni cita
# material de otro cliente (invariante 10), y esa frontera se comprueba con un
# `where` sobre `platform_client_id`, no navegando asociaciones.
class Platform::Client < Platform::Record
  # La clave foránea va explícita en las cinco. Dentro de `module Platform`,
  # Rails la deduce del nombre desmodulizado —`client_id`— y la columna se llama
  # `platform_client_id`: sin esto, cada asociación revienta la primera vez que
  # alguien la usa, y no antes.
  has_many :platform_projects, class_name: "Platform::Project",
                               foreign_key: :platform_client_id,
                               inverse_of: :platform_client,
                               dependent: :restrict_with_exception
  has_many :platform_documents, class_name: "Platform::Document",
                                foreign_key: :platform_client_id,
                                inverse_of: :platform_client,
                                dependent: :restrict_with_exception
  has_many :platform_meetings, class_name: "Platform::Meeting",
                               foreign_key: :platform_client_id,
                               inverse_of: :platform_client,
                               dependent: :restrict_with_exception
  has_many :repositories, foreign_key: :platform_client_id,
                          inverse_of: :platform_client,
                          dependent: :restrict_with_exception
  has_many :initiatives, foreign_key: :platform_client_id,
                         inverse_of: :platform_client,
                         dependent: :restrict_with_exception

  validates :platform_id, presence: true, uniqueness: true
  # El slug va dentro de claves de artefacto inmutables: se congela en la
  # primera sincronización y no se refresca nunca. El nombre sí.
  validates :slug, presence: true, uniqueness: true,
                   format: { with: /\A[a-z0-9]+(?:-[a-z0-9]+)*\z/ }
  validates :name, presence: true

  scope :active, -> { where(archived: false) }

  def to_s = name
end
