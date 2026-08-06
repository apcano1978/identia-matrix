# La configuración de un agente. Nula por cliente = global.
#
# La efectiva es `global.deep_merge(override)`: el override de un cliente ajusta
# lo que necesita y hereda el resto, para que cambiar el global no deje a los
# clientes con configuraciones fosilizadas.
class AgentConfig < ApplicationRecord
  belongs_to :platform_client, class_name: "Platform::Client", optional: true
  belongs_to :updated_by_user, class_name: "Platform::User", optional: true

  enum :agent, { tank: 0, neo: 1, seraph: 2, morfeo: 3, trinity: 4, link: 5 },
       prefix: true, validate: true

  validates :agent, uniqueness: { scope: :platform_client_id }

  scope :global, -> { where(platform_client_id: nil) }

  def global? = platform_client_id.nil?

  # La configuración con la que se ejecuta el agente para un cliente dado.
  def self.effective_for(agent:, client: nil)
    base = global.find_by(agent: agent)&.settings || {}
    return base.deep_dup if client.blank?

    override = find_by(agent: agent, platform_client_id: client)&.settings || {}
    base.deep_merge(override)
  end
end
