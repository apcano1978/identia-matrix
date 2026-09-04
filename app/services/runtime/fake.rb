# El runtime falso: devuelve el markdown del fixture del par (agente,
# propósito), con un retardo configurable para que el event stream de F3 tenga
# algo que enseñar.
#
# Cero retardo en test, siempre: un `sleep` en la suite es un impuesto que se
# paga en cada ejecución y no compra nada.
module Runtime::Fake
  DEFAULT_DELAY = 0.4

  module_function

  def run(request)
    metadata, body = Runtime::Fixture.read(agent: request.agent,
                                           purpose: request.purpose)
    pause

    {
      "contract_version" => Runtime::Request::CONTRACT_VERSION,
      "agent" => request.agent,
      "purpose" => request.purpose,
      "body" => interpolate(body, request),
      "citations" => metadata.fetch("citations", []),
      "events" => metadata.fetch("events", []),
      "findings" => metadata.fetch("findings", []),
      "usage" => metadata.fetch("usage", default_usage),
      "request_id" => "fake-#{SecureRandom.hex(6)}"
    }
  end

  # El fixture habla de ev-031 y de vivla porque son los de la maqueta. Cuando
  # se ejecuta sobre otro evolutivo, el cuerpo lo dice: un dossier que afirma
  # ser de otro cliente sería material para confundirse en una demo.
  # Del `config`, que es donde vive el contexto del evolutivo desde F9. Antes
  # estaba en `context`, y ese cambio se notó AQUÍ primero: el cuerpo salía con
  # el cliente y el evolutivo en blanco, que es exactamente el fallo que este
  # fixture existe para no tener en una demo.
  def interpolate(body, request)
    config = request.payload["config"]

    body.gsub("{{initiative}}", config.dig("initiative", "code").to_s)
        .gsub("{{title}}", config.dig("initiative", "title").to_s)
        .gsub("{{client}}", config.dig("client", "slug").to_s)
  end

  def pause
    return if Rails.env.test?

    seconds = ENV.fetch("MATRIX_AGENT_RUNTIME_DELAY", DEFAULT_DELAY).to_f
    sleep(seconds) if seconds.positive?
  end

  def default_usage = { "input_tokens" => 0, "output_tokens" => 0 }
end
