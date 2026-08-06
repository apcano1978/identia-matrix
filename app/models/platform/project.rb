# El «proyecto» de platform, y el único sitio del sistema donde esa palabra
# significa algo. Matrix trabaja con repositorios y evolutivos; un proyecto de
# platform es un contrato comercial que puede abarcar varios de ambos.
#
# Nunca se escribe `Project` a secas: el vocabulario lo vigila
# `test/architecture/vocabulary_test.rb`.
class Platform::Project < Platform::Record
  belongs_to :platform_client, class_name: "Platform::Client"

  has_many :platform_documents, class_name: "Platform::Document",
                                foreign_key: :platform_project_id,
                                inverse_of: :platform_project,
                                dependent: :restrict_with_exception
  has_many :platform_meetings, class_name: "Platform::Meeting",
                               foreign_key: :platform_project_id,
                               inverse_of: :platform_project,
                               dependent: :restrict_with_exception
  has_many :initiatives, foreign_key: :platform_project_id,
                         inverse_of: :platform_project, dependent: :nullify

  validates :platform_id, presence: true, uniqueness: true
  validates :platform_project_ref, presence: true, uniqueness: true
  validates :name, presence: true

  scope :active, -> { where(archived: false) }

  def to_s = "#{platform_project_ref} · #{name}"
end
