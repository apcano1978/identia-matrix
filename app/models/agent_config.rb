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

  # Los ajustes que un cliente NO puede sobrescribir (F2 §1.5). La maqueta las
  # marca como no configurables y tiene razón: son las tres que sostienen
  # invariantes, y un cliente que se diera dos vueltas más de MORFEO o un tercer
  # ciclo de QA estaría comprando una política distinta, no un ajuste.
  #
  # ⚠ SON LITERALES, y ese es su punto débil. Escritas de dos formas distintas
  # —aquí y en el seed— el bloqueo no se aplica y nadie se entera: la clave
  # simplemente no coincide y el override pasa. Por eso hay un test que
  # comprueba que cada una de estas rutas EXISTE en la configuración global; si
  # alguien renombra un ajuste, se pone rojo en vez de dejar de proteger en
  # silencio.
  # F2 §1.5 listaba una tercera, `link.independence`, y al ir a aplicarla resultó
  # que NO EXISTE: la configuración de LINK no tiene tal ajuste, ni lo tuvo
  # nunca. Es justo el fallo que el aviso de arriba anticipaba, y aparece aquí
  # con la mejor de las causas: la independencia de LINK ya no es configurable
  # de ninguna manera, porque desde F9 la impone el código —`Runtime::Request::
  # MATERIAL` no le da a LINK ni el dossier ni las fuentes—. Bloquear un ajuste
  # inexistente habría dado la sensación de proteger algo sin proteger nada.
  LOCKED_KEYS = {
    "neo" => %w[morfeo_loop.max_returns],
    "seraph" => %w[qa_cycle.max_qa_cycles]
  }.freeze

  def global? = platform_client_id.nil?

  def self.locked_for(agent) = LOCKED_KEYS.fetch(agent.to_s, [])

  # Quita de un override las claves que no son suyas. No es validación —no
  # rechaza, poda—: quien manda un ajuste bloqueado desde un formulario
  # manipulado obtiene el resto de su cambio y esa clave intacta, que es lo que
  # el sistema quería decir.
  def self.without_locked(settings, agent:)
    result = settings.deep_dup

    locked_for(agent).each do |path|
      keys = path.split(".")
      parent = keys[0..-2].inject(result) { |node, key| node.is_a?(Hash) ? node[key] : nil }
      next unless parent.is_a?(Hash)

      parent.delete(keys.last)
      # Y el contenedor, si se queda vacío. Un `"morfeo_loop" => {}` colgando en
      # el override no cambia nada al fusionar —`deep_merge` con un hash vacío es
      # la identidad— pero le dice a quien lo lea que ahí hay un ajuste, y no lo
      # hay.
      prune_empty(result, keys[0..-2])
    end

    result
  end

  # Quita los contenedores que se quedaron vacíos al podar, de dentro afuera.
  def self.prune_empty(settings, keys)
    keys.length.downto(1) do |depth|
      branch = keys[0...depth]
      parent = depth == 1 ? settings : settings.dig(*branch[0..-2])
      break unless parent.is_a?(Hash) && parent[branch.last] == {}

      parent.delete(branch.last)
    end
  end
  private_class_method :prune_empty

  # La configuración con la que se ejecuta el agente para un cliente dado.
  def self.effective_for(agent:, client: nil)
    base = global.find_by(agent: agent)&.settings || {}
    return base.deep_dup if client.blank?

    override = find_by(agent: agent, platform_client_id: client)&.settings || {}
    base.deep_merge(override)
  end
end
