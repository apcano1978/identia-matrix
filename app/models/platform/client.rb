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

  # **En preparación**: está en matrix porque alguien lo admitió, no porque tenga
  # trabajo en marcha. Es la fase previa al evolutivo, cuando se está reuniendo
  # la documentación y el proyecto todavía no existe en platform.
  #
  # Se DERIVA y no se guarda en columna: el dato es de platform y cambia solo, en
  # cuanto el proyecto aparezca. Y son las dos condiciones, no una: sin la
  # admisión, «sin proyectos vivos» describiría también a un cliente que terminó
  # el suyo, que es un caso distinto y lo cuenta `missing_since`.
  #
  # `admitted_ids` se puede pasar ya resuelto para no preguntar una vez por fila
  # en el índice; sin él, la pregunta se hace sola.
  def admitted?(admitted_ids = nil)
    return admitted_ids.include?(platform_id) if admitted_ids

    ClientAdmission.exists?(platform_id: platform_id)
  end

  def in_preparation?(admitted_ids = nil)
    admitted?(admitted_ids) && platform_projects.none? { |project| project.missing_since.nil? }
  end

  # La URL habla en slug, no en id: `param: :slug` en las rutas cambia el nombre
  # del segmento pero NO lo que `client_path(client)` mete dentro. Sin esto, los
  # enlaces salen con el id y el `find_by!(slug:)` no encuentra nada.
  def to_param = slug

  def to_s = name
end
