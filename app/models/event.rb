# La narrativa: el event stream que la maqueta pinta como una lista de líneas.
#
# No es redundante con `stage_entries`. Aquel es estado estructurado y
# consultable —la tira de doce glifos—; esto es lo que pasó, contado. La maqueta
# necesita los dos, y un evento no siempre pertenece a un evolutivo:
# «SYNC vivla · 14 docs» es del cliente y de nadie más.
class Event < ApplicationRecord
  belongs_to :initiative, optional: true
  belongs_to :platform_client, class_name: "Platform::Client", optional: true

  validates :occurred_at, presence: true
  validates :actor, presence: true
  validates :kind, presence: true
  validates :message, presence: true

  scope :recent, -> { order(occurred_at: :desc, id: :desc) }
  scope :for_client, ->(client) { where(platform_client_id: client) }

  def to_s = "#{actor} · #{message}"
end
