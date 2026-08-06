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

  # Lo que el panel enseña de una vez. Más allá de esto nadie lee un log: se
  # consulta el historial del evolutivo, que es donde está entero.
  STREAM_SIZE = 10

  scope :recent, -> { order(occurred_at: :desc, id: :desc) }
  scope :for_client, ->(client) { where(platform_client_id: client) }

  # El event stream se actualiza por Turbo DESDE AQUÍ, y no desde los cinco
  # servicios de `Pipeline::*` como proponía la guía. Los cinco pasan ya por
  # `Pipeline::Transition#record_event`, que crea esta fila: un solo sitio, y
  # cubre además los eventos que no nacen de una transición —el `SYNC vivla ·
  # 14 docs` que emitirá F8—.
  after_create_commit :broadcast_to_stream

  def to_s = "#{actor} · #{message}"

  private
    def broadcast_to_stream
      broadcast_prepend_to("events", target: "event-stream",
                                     partial: "events/event", locals: { event: self })
    end
end
