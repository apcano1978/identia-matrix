# frozen_string_literal: true

# El acta del ARQUITECTO en pantalla.
module ActasHelper
  # Los glifos del rediseño, y son DOS y no tres: cerrada y descartada comparten
  # el punto lleno porque las dos están decididas. Lo que el glifo separa es
  # «decidido» de «pendiente», que es la única distinción que importa de un
  # vistazo; la palabra de al lado dice cuál de las dos.
  GLYPHS = { "open" => "◆", "closed" => "●", "discarded" => "●" }.freeze

  # Descartada va en apagado y no en el verde de cerrada: está decidida, pero lo
  # que se decidió es que queda fuera. Pintarla igual que una cerrada haría
  # parecer que el trabajo la cubre.
  TONES = { "open" => "text-glyph-active", "closed" => "text-glyph-done",
            "discarded" => "text-terminal-fg-4" }.freeze

  def decision_glyph(decision) = GLYPHS.fetch(decision.status)

  def decision_tone(decision) = TONES.fetch(decision.status)

  # `ARQUITECTO · 4 sesiones · 214k tokens`. El coste del acta se cuenta como el
  # de cualquier otro agente porque **cada turno es un `AgentRun`**: no hay una
  # segunda forma de hablar con el brain, y por eso no hace falta un contador
  # aparte para la conversación.
  def acta_cost_note(runs)
    return "ARQUITECTO · sin sesiones" if runs.blank?

    "ARQUITECTO · #{pluralize(runs.size, 'sesión', plural: 'sesiones')} · " \
      "#{token_total(runs)}"
  end
end
