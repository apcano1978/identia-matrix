# El eje de TRABAJO: un evolutivo. Recorre las doce etapas, cruza uno o varios
# repositorios y muere cuando se publica.
#
# No es hijo de Repository ni padre suyo: se cruzan en `initiative_repositories`,
# que es la matriz evolutivo × repositorio de la ficha de cliente.
class Initiative < ApplicationRecord
  include FrozenSlug

  # Las doce etapas, en orden. El orden ES el dato: `Pipeline::Advance` avanza
  # por él y los saltos hacia atrás se miden contra él.
  STAGES = %w[
    need tank neo seraph_dod morfeo trinity
    gate_1 claude_code seraph_verification gate_2 link publication
  ].freeze

  # Tope de ciclos de QA. Un tercer ✕ no gasta un ciclo que no existe: escala.
  MAX_QA_CYCLES = 2

  belongs_to :project

  # El cliente ya no es una columna: se responde A TRAVÉS DEL PROYECTO, que es
  # donde vive. La frase «el cliente de un evolutivo» sigue siendo verdad; lo que cambió es
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
  belongs_to :platform_project, class_name: "Platform::Project", optional: true

  has_many :initiative_repositories, dependent: :destroy
  has_many :repositories, through: :initiative_repositories
  has_many :stage_entries, dependent: :destroy
  has_many :agent_runs, dependent: :destroy
  has_many :events, dependent: :nullify
  has_many :escalations, dependent: :destroy
  has_many :human_notes, dependent: :destroy
  has_many :definitions_of_done, dependent: :destroy
  has_many :verification_reports, dependent: :destroy
  has_many :work_packages, dependent: :destroy
  has_many :gate_signatures, dependent: :destroy
  has_many :test_guides, dependent: :destroy
  has_many :gate_validations, dependent: :destroy
  has_many :artifacts, dependent: :destroy
  has_many :initiative_sources, dependent: :destroy
  has_many :initiative_roles, dependent: :destroy
  # El acta del ARQUITECTO, fila a fila (F11 · B8). `destroy` y no `nullify`: una
  # decisión sin evolutivo no es nada — a diferencia de un evento, que narra algo
  # que pasó aunque el evolutivo desaparezca.
  has_many :decisions, dependent: :destroy

  enum :current_stage, STAGES.each_with_index.to_h, prefix: :at, validate: true
  enum :current_stage_status,
       { pending: 0, active: 1, done: 2, failed: 3, escalated: 4 },
       prefix: :status, validate: true

  # EL NOMBRE, y lo que va dentro de la clave del artefacto desde F11.
  #
  # Kebab estricto —el `SLUG` de `Artifacts::Key`, solo guiones— y único DENTRO
  # del proyecto: dos proyectos pueden tener cada uno su `rediseno-interfaz`, y
  # lo que hace única una clave es la pareja proyecto + evolutivo.
  #
  # ⚠ PROHIBIDO PARECERSE A UN CÓDIGO DE ARTEFACTO. Un evolutivo llamado
  # `spec-031` haría ambiguo el locator de `[src:spec/spec-031]`, que desde F11
  # puede nombrar tanto el código del artefacto como el slug del evolutivo. Con
  # esta guarda los dos espacios de nombres no se solapan y la resolución sigue
  # siendo determinista.
  #
  # `ev-031` SÍ se admite: es lo que deja el relleno de la migración, y por eso
  # ninguna clave ya emitida deja de ser válida.
  #
  # Sin tope de longitud, igual que en `Project` y por lo mismo: el tope de
  # cuarenta es una regla del formulario de alta, no de la raíz del modelo.
  ARTIFACT_CODE = /\A(?:dossier|spec|dod|pkg|verify|guia-pruebas|close|arquitecto)-\d{3,}\z/

  validates :slug, presence: true,
                   uniqueness: { scope: :project_id },
                   format: { with: /\A#{Artifacts::Key::SLUG}\z/ }
  validate :slug_is_not_an_artifact_code

  validates :code, presence: true, uniqueness: true,
                   format: { with: /\Aev-\d{3,}\z/ }
  validates :title, presence: true
  validates :opened_at, presence: true
  validates :iteration, numericality: { greater_than_or_equal_to: 1 }
  validates :qa_cycles_consumed,
            numericality: { in: 0..MAX_QA_CYCLES }

  scope :open, -> { where.not(current_stage: :publication) }

  # El número que comparten los artefactos del evolutivo: ev-031 → 31.
  # Del CÓDIGO, no del slug: un slug no lleva número. De aquí salen los códigos
  # de artefacto (`ev-031` → `dod-031`), y es media razón de que `code` siga
  # existiendo.
  def number = code.delete_prefix("ev-").to_i

  def multi_repo? = initiative_repositories.size > 1

  # ¿Alguien decidió QUÉ fuentes entran, o entra todo lo que haya? (F12 · B5)
  #
  # La pregunta no la contesta el conteo de `initiative_sources`, y ahí está el
  # porqué de la columna: sin ella, cero filas significaba «todas» y no había
  # forma de decir «ninguna». Con ella, recortar es un acto fechado.
  #
  # Lo que hace con la respuesta es `Sources::Scope.in_scope`, que es donde vive
  # el concepto de ámbito.
  def sources_scoped? = sources_scoped_at.present?

  def qa_cycles_exhausted? = qa_cycles_consumed >= MAX_QA_CYCLES

  # La escalada abierta, si la hay. Un evolutivo detenido tiene exactamente una.
  def open_escalation = escalations.find { |e| e.resolved_at.nil? }

  # Espera a una persona: está en una de las dos puertas o está detenido. Vive
  # en el modelo y no en el dashboard porque lo preguntan tres pantallas, y tres
  # copias de esta condición acabarían discrepando.
  def awaiting_human?
    at_gate_1? || at_gate_2? || open_escalation.present?
  end

  # La URL habla en NOMBRE desde F11. `code` sigue siendo la identidad interna
  # —y la que viaja al brain, donde su forma está congelada— pero no es lo que
  # se lee en una barra de direcciones.
  def to_param = slug

  def to_s = "#{code} · #{title}"

  private
    def slug_is_not_an_artifact_code
      return if slug.blank? || !slug.match?(ARTIFACT_CODE)

      errors.add(:slug, "no puede tener forma de código de artefacto: haría " \
                        "ambigua una cita como [src:spec/#{slug}]")
    end
end
