# frozen_string_literal: true

module AgentsHelper
  ROLES = {
    "tank" => "contexto · indexa el repositorio y las fuentes del cliente",
    "neo" => "dossier → especificación técnica + ADR",
    "morfeo" => "revisión · spec y DoD antes de ejecutar",
    "trinity" => "plan · sella el paquete de trabajo",
    "seraph" => "verificación · redacta el DoD y comprueba contra él",
    "link" => "cierre documental · narra el desvío frente al plan"
  }.freeze

  CADENCE = {
    "seraph" => "interviene 2 veces por ciclo",
    "link" => "interviene 1 vez · tras GATE 2"
  }.freeze

  # Los tres avisos que la guía manda conservar LITERALES. No son texto de
  # relleno: son reglas del sistema, y explican por qué esas claves no se pueden
  # tocar. Van con la sección a la que pertenecen.
  NOTES = {
    [ "neo", "morfeo_loop" ] => {
      glyph: "▣", tone: "text-antique-gold",
      text: "Superado el límite, el ciclo escala a revisión humana en vez de " \
            "reintentar. No sobrescribible por cliente."
    },
    [ "seraph", "qa_cycle" ] => {
      glyph: "⊘", tone: "text-glyph-fail",
      text: "Agotados los ciclos el flujo se detiene. Solo un humano lo reinicia " \
            "con una nota, que entra como ◆ ORIGEN. La escalada queda en el " \
            "historial."
    },
    [ "link", "publicacion" ] => {
      glyph: "!", tone: "text-antique-gold",
      text: "LINK no comparte contexto de redacción con NEO. Quien escribió el " \
            "plan es el peor narrador del desvío frente al plan. No configurable."
    }
  }.freeze

  # Postgres NO conserva el orden de las claves de un `jsonb`: las devuelve por
  # longitud y luego alfabéticamente, que no se parece a ningún orden de lectura.
  #
  # Las secciones llevan orden propio —el del trabajo del agente: primero lo que
  # escribe, luego cómo verifica, luego qué dictamina—; lo que no esté en la
  # lista va detrás, alfabético, para que añadir una sección en F9 no la esconda.
  SECTION_ORDER = %w[
    contexto model sources citation_rules morfeo_loop revision paquete
    dod_pass qa_cycle verificacion dictamen contenido_del_cierre publicacion
  ].freeze

  def ordered_sections(effective)
    effective.sort_by do |section, _|
      [ SECTION_ORDER.index(section) || SECTION_ORDER.size, section ]
    end
  end

  # Y dentro de una sección, alfabético: es una regla que se puede predecir,
  # frente al orden de `jsonb`, que no.
  def ordered_settings(entries) = entries.sort_by { |key, _| key }

  def agent_role(agent) = ROLES.fetch(agent)
  def agent_cadence(agent) = CADENCE[agent]
  def agent_note(agent, section) = NOTES[[ agent, section ]]

  # Un booleano se pinta como casilla y un valor como valor. Es lo que hace que
  # la pantalla se lea de un vistazo sin saber qué tipo tiene cada clave.
  def setting_value(value)
    case value
    when true then tag.span("[✓]", class: "text-glyph-done")
    when false then tag.span("[ ]", class: "text-terminal-disabled")
    else tag.span(value, class: "text-terminal-fg")
    end
  end

  def humanize_key(key) = key.to_s.tr("_", " ")

  # Lo que el override cambia respecto a la global, aplanado a `a.b = valor`.
  def override_diff(override, global)
    flatten_settings(override).filter_map do |path, value|
      before = flatten_settings(global)[path]
      next if before == value

      { path: path, before: before, after: value }
    end
  end

  def flatten_settings(settings, prefix = nil)
    settings.each_with_object({}) do |(key, value), flat|
      path = [ prefix, key ].compact.join(".")
      value.is_a?(Hash) ? flat.merge!(flatten_settings(value, path))
                        : flat[path] = value
    end
  end
end
