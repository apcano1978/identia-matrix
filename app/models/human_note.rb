# Lo que una persona escribió. Es fuente de ORIGEN de pleno derecho: una nota
# humana pesa lo mismo que un documento o un acta, y por eso se puede citar
# —[src:note/2026-05-08-ap]— y por eso tiene código propio y estable.
class HumanNote < ApplicationRecord
  belongs_to :initiative
  belongs_to :platform_client, class_name: "Platform::Client"
  belongs_to :author_user, class_name: "Platform::User"

  has_many :escalations, dependent: :nullify
  has_many :citations, as: :target, dependent: :nullify

  validates :code, presence: true, uniqueness: true,
                   format: { with: /\A\d{4}-\d{2}-\d{2}-[a-z0-9]+(?:-[a-z0-9]+)*\z/ }
  validates :body, presence: true

  scope :chronological, -> { order(:created_at) }

  def citation = "[src:note/#{code}]"
end
