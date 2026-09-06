# Un cliente admitido en matrix antes de tener proyecto.
#
# El catálogo de clientes lo decide `Platform::HttpSource#clients` mirando quién
# tiene trabajo en marcha. Esta tabla es la lista de excepciones a esa regla, y
# es una lista de nombres propios: cada fila deja entrar a UN cliente y dice por
# qué. La regla no se toca — un lead en negociación no tiene nada que evolucionar
# y no debe aparecer solo por existir.
#
# Lo que habilita es la fase anterior al evolutivo: reunir la documentación y las
# guías de desarrollo del cliente mientras el proyecto se está preparando. No
# habilita abrir un evolutivo — eso sigue exigiendo al menos un repositorio,
# porque un evolutivo es trabajo *sobre* código y sin repositorio no habría nada
# que citar.
#
# **Retirarla es borrar la fila.** Sin `revoked_at` y sin `update`, como
# `RepositoryCredential`: lo que matrix escribe son actos que ocurren una vez.
# Al desaparecer, el cliente cae del catálogo y la proyección lo marca con
# `missing_since` en lugar de borrarlo, que es lo correcto si ya tenía citas.
class ClientAdmission < ApplicationRecord
  # El id del lead en platform. No hay `belongs_to`: cuando se admite a alguien
  # su fila en la proyección todavía no existe.
  validates :platform_id, presence: true, uniqueness: true,
                          numericality: { only_integer: true, greater_than: 0 }
  # Sin motivo no se admite. Es lo único que distingue una excepción de una
  # puerta abierta, y dentro de seis meses es lo único que explicará la fila.
  validates :reason, presence: true
  validates :admitted_by, presence: true

  scope :latest_first, -> { order(created_at: :desc, id: :desc) }

  # Los ids que amplían el catálogo, resueltos aquí para que `HttpSource` los
  # reciba ya hechos: esa clase habla HTTP y no toca la base de datos.
  def self.platform_ids = pluck(:platform_id).to_set

  def to_s = "#{platform_id} · #{reason} · #{admitted_by}"
end
