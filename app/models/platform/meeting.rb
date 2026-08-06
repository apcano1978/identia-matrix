# Una transcripción de reunión. Fuente de ORIGEN: lo que citan [src:meet/...].
#
# Las citas de reunión resuelven por FECHA, con el slug como desempate opcional
# —`[src:meet/2026-05-02-precios]`— porque así se nombran las reuniones al
# hablar de ellas. Ver Citations::Grammar.
class Platform::Meeting < Platform::Record
  belongs_to :platform_client, class_name: "Platform::Client"
  belongs_to :platform_project, class_name: "Platform::Project", optional: true

  has_many :initiative_sources, as: :source, dependent: :destroy
  has_many :citations, as: :target, dependent: :nullify

  validates :platform_id, presence: true, uniqueness: true
  validates :slug, presence: true, uniqueness: true,
                   format: { with: /\A[a-z0-9]+(?:-[a-z0-9]+)*\z/ }
  validates :title, presence: true
  validates :held_on, presence: true

  scope :held_on_date, ->(date) { where(held_on: date) }

  def citable? = body.present?

  # El localizador tal como aparece dentro de la cita.
  def citation_locator = "#{held_on.iso8601}-#{slug}"

  def to_s = "#{held_on.iso8601} · #{title}"
end
