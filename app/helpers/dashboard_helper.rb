# frozen_string_literal: true

module DashboardHelper
  TRAY_BORDERS = {
    gold: "border-terminal-border-gold", gate2: "border-terminal-border-strong",
    fail: "border-terminal-border-fail", muted: "border-terminal-border"
  }.freeze

  # El tono de una línea del event stream sale de su `kind`, no del actor: el
  # mismo agente escribe cosas buenas y malas, y lo que hay que poder ver de un
  # vistazo es cuál de las dos.
  EVENT_TONES = {
    "escalated" => "text-glyph-fail",
    "sent_back" => "text-glyph-fail",
    "restarted" => "text-antique-gold",
    "published" => "text-glyph-done",
    "stage_advanced" => "text-antique-gold"
  }.freeze

  def tray_border_class(tone) = TRAY_BORDERS.fetch(tone)
  def event_tone_class(event) = EVENT_TONES.fetch(event.kind, "text-terminal-fg-3")

  # `10:04:18` mientras es de hoy; `ayer` y la fecha después. Un log de terminal
  # enseña la hora, no la fecha: lo que importa es hace cuánto.
  def event_time(event)
    occurred = event.occurred_at

    case occurred.to_date
    when Date.current then occurred.strftime("%H:%M:%S")
    when Date.yesterday then "ayer"
    else I18n.l(occurred.to_date, format: :short)
    end
  end

  def event_scope(event)
    [ event.platform_client&.slug, event.initiative&.code ].compact.join("/")
  end

  # `4.82 M tok`. El consumo de hoy, agregado de agent_runs.
  # A dónde lleva el botón de cada bandeja. Desde F6, a la puerta que hay que
  # atender: una decisión se toma delante de lo que se está decidiendo, no
  # desde una lista.
  def tray_destination(initiative, action)
    client = initiative.platform_client

    case action
    when "firmar" then client_initiative_gate_1_path(client, initiative)
    when "validar" then client_initiative_gate_2_path(client, initiative)
    else client_initiative_path(client, initiative)
    end
  end

  def token_total(runs)
    tokens = runs.sum { |run| run.total_tokens }

    return "#{tokens} tok" if tokens < 1_000
    return "#{(tokens / 1_000.0).round(1)} K tok" if tokens < 1_000_000

    "#{(tokens / 1_000_000.0).round(2)} M tok"
  end
end
