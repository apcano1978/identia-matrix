# La credencial con la que matrix LEE los repositorios de un cliente (F8 §B.2).
#
# Cifrada at-rest. Solo lectura por contrato con el cliente: matrix no escribe
# en un repositorio ajeno en ninguna fase — el único que lo hace es Claude Code
# tras GATE 1, y esa es otra cadena.
#
# **Rotar es emitir otra.** Manda la más reciente; las anteriores se quedan como
# rastro de cuándo se cambió. No hay `revoked_at` ni `update` porque matrix no
# tiene ninguno: lo que escribe son actos que ocurren una vez.
class RepositoryCredential < ApplicationRecord
  encrypts :token

  belongs_to :platform_client, class_name: "Platform::Client"

  validates :host, presence: true
  validates :token, presence: true

  # La vigente de un cliente para un host. Por `created_at` y con `id` de
  # desempate: dos emitidas en la misma transacción comparten instante.
  scope :latest_first, -> { order(created_at: :desc, id: :desc) }

  def self.current_for(client, host)
    where(platform_client: client, host: host).latest_first.first
  end

  # Nunca el valor. Lo que se enseña de una credencial es que existe y desde
  # cuándo, igual que en la UI de tokens de platform.
  def to_s = "#{host} · emitida #{I18n.l(created_at.to_date, format: :short)}"
end
