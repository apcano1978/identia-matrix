# El paquete de trabajo de TRINITY: lo que se va a firmar en GATE 1.
#
# Se SELLA antes de firmarse. Sellar congela su contenido en `content_hash`, y
# la firma guarda ese hash: si alguien vuelve a sellar después, la firma sigue
# diciendo sobre qué se firmó.
class WorkPackage < ApplicationRecord
  belongs_to :initiative
  belongs_to :agent_run, optional: true
  belongs_to :artifact, optional: true

  has_many :work_package_repositories, dependent: :destroy
  has_many :repositories, through: :work_package_repositories
  has_one :gate_signature, dependent: :restrict_with_exception

  validates :code, presence: true, uniqueness: true

  scope :sealed, -> { where.not(sealed_at: nil) }

  def sealed? = sealed_at.present?
  def signed? = gate_signature.present?

  def multi_repo? = work_package_repositories.size > 1

  # Un paquete multi-repo SIN orden de despliegue está incompleto: durante la
  # ventana convive una versión nueva con una vieja, y MORFEO lo marca
  # bloqueante en vez de dejar que se firme.
  def deploy_order_complete?
    rows = work_package_repositories.to_a
    rows.any? && rows.all? { |r| r.deploy_order.present? }
  end

  def deploy_sequence
    work_package_repositories.sort_by(&:deploy_order)
  end

  def to_s = code
end
