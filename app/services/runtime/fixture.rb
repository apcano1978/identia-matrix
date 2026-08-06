# Un fixture de `lib/runtime/fixtures/<agente>/<propósito>.md`.
#
# El fichero lleva front-matter YAML con lo que no es cuerpo —citas, eventos,
# hallazgos, consumo— y debajo el markdown. Guardar las dos cosas juntas hace
# que el fixture se lea como lo que imita: la respuesta entera de un agente, no
# un trozo suelto.
module Runtime::Fixture
  ROOT = Rails.root.join("lib/runtime/fixtures")
  DELIMITER = "---".freeze

  module_function

  def path(agent:, purpose:) = ROOT.join(agent.to_s, "#{purpose}.md")

  def exists?(agent:, purpose:) = path(agent: agent, purpose: purpose).exist?

  def read(agent:, purpose:)
    file = path(agent: agent, purpose: purpose)

    unless file.exist?
      raise Runtime::MissingFixture,
            "no hay fixture para #{agent}/#{purpose} en " \
            "#{file.relative_path_from(Rails.root)}"
    end

    split(file.read)
  end

  # Devuelve [metadatos, cuerpo].
  def split(document)
    match = /\A#{DELIMITER}\n(?<yaml>.*?)\n#{DELIMITER}\n(?<body>.*)\z/m
            .match(document)

    return [ {}, document ] if match.blank?

    [ YAML.safe_load(match[:yaml]) || {}, match[:body].lstrip ]
  end

  def available
    ROOT.glob("*/*.md").map do |file|
      [ file.parent.basename.to_s, file.basename(".md").to_s ]
    end.sort
  end
end
