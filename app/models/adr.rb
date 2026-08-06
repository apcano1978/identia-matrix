# Una decisión de arquitectura de un repositorio. Vive en el eje de MEMORIA: no
# pertenece al evolutivo que la originó, sino al repositorio que la arrastra.
#
# `disputed` es lo que pasa cuando un evolutivo nuevo la contradice. No se borra
# ni se reescribe: se marca, y alguien decide.
class Adr < ApplicationRecord
  belongs_to :repository
  belongs_to :origin_initiative, class_name: "Initiative", optional: true

  enum :status, { current: 0, disputed: 1 }, prefix: true, validate: true

  validates :code, presence: true, uniqueness: { scope: :repository_id }
  validates :title, presence: true

  def to_s = "#{code} · #{title}"
end
