# El resultado de la integración continua de UN repositorio para UN informe.
#
# `commit_sha` es el commit EJECUTADO, distinto del sellado en GATE 1: son dos
# sha por par (evolutivo, repositorio) y colapsarlos perdería la única forma de
# saber sobre qué se firmó y sobre qué se verificó.
class CiCheck < ApplicationRecord
  belongs_to :verification_report
  belongs_to :repository

  # Los bytes del log. `unavailable` es un estado legítimo: un repositorio sin
  # CI configurada lo dice en vez de fingir que verifica.
  has_one_attached :log

  enum :status, { green: 0, red: 1, unavailable: 2 }, prefix: true,
       validate: true

  validates :commit_sha, presence: true
  validates :repository_id, uniqueness: { scope: :verification_report_id }

  def to_s = "#{repository&.name} · #{status}"
end
