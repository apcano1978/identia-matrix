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
      # La lista declarada se interpola igual que el cuerpo. El contrato la
      # valida contra la gramática y matrix la contrasta con lo que el cuerpo
      # cita: si una se reescribe y la otra no, dejan de coincidir.
      "citations" => metadata.fetch("citations", []).map { |c| interpolate(c, request) },
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

    repoint_code(
      body.gsub("{{initiative}}", config.dig("initiative", "code").to_s)
          .gsub("{{title}}", config.dig("initiative", "title").to_s)
          # El proyecto de respaldo: un proyecto PROPIO no tiene cliente, y el
          # cuerpo saldría con el hueco en blanco.
          .gsub("{{client}}", config.dig("client", "slug").presence ||
                              config.dig("project", "slug").to_s),
      config)
  end

  # ⚠ REAPUNTA LAS CITAS DE CÓDIGO al repositorio del evolutivo que se está
  # ejecutando, y es una propiedad del runtime FALSO, no del sistema.
  #
  # Un fixture está escrito para un mundo —el del seed, donde el repositorio se
  # llama `booking-core`— y se ejecuta en otro. Sobre un evolutivo que no lo
  # tiene, `Citation` rechaza la cita: **el calificador de repositorio es
  # obligatorio en una cita de código** y no puede resolver contra un
  # repositorio que no está en el proyecto. Es el invariante haciendo su
  # trabajo, no un fallo — así que lo que se corrige es el fixture, aquí, y no
  # la validación.
  #
  # No se puede hacer con un marcador `{{...}}` porque la cita entera tiene que
  # parsear contra la gramática **también en el fichero sin interpolar**: es lo
  # que `fixtures_test` comprueba, y es lo que hace que los fixtures sean el
  # único texto real contra el que el parser se prueba.
  def repoint_code(body, config)
    repository = config.fetch("repositories", []).first&.fetch("name", nil)
    return body if repository.blank?

    body.gsub(%r{\[src:code/[a-z0-9]+(?:-[a-z0-9]+)*:}, "[src:code/#{repository}:")
  end

  def pause
    return if Rails.env.test?

    seconds = ENV.fetch("MATRIX_AGENT_RUNTIME_DELAY", DEFAULT_DELAY).to_f
    sleep(seconds) if seconds.positive?
  end

  def default_usage = { "input_tokens" => 0, "output_tokens" => 0 }
end
