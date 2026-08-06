# frozen_string_literal: true

# El armazón: qué entrada del rail se ilumina, qué dice el breadcrumb y qué
# resume la barra de título.
module ShellHelper
  # El mapeo de vista a entrada NO es uno a uno. Siete vistas —clientes, ficha,
  # evolutivo, repositorio, fuentes, DoD, verificación y GATE 2— iluminan
  # CLIENTES, porque todas son el mismo recorrido: entrar en el trabajo de un
  # cliente. GATE 1 ilumina DASHBOARD, que es de donde se llega a firmar.
  RAIL_SECTIONS = {
    "dashboard" => :dashboard,
    "gates" => :dashboard,
    "clients" => :clients,
    "initiatives" => :clients,
    "repositories" => :clients,
    "sources" => :clients,
    "agents" => :agents
  }.freeze

  RAIL_ENTRIES = [
    [ :dashboard, "DASHBOARD" ], [ :clients, "CLIENTES" ], [ :agents, "AGENTES" ]
  ].freeze

  def rail_section = RAIL_SECTIONS[controller_name]

  def rail_entry_class(section)
    section == rail_section ? "rail-entry rail-entry-on" : "rail-entry"
  end

  def rail_label_class(section)
    section == rail_section ? "rail-label text-terminal-fg" : "rail-label"
  end

  # `clients/vivla/ev-031`. Se declara desde la vista y la pinta la barra de
  # título, que se renderiza antes: por eso va por `content_for` y no por una
  # variable de instancia.
  def breadcrumb(*parts)
    content_for(:breadcrumb, parts.compact.join("/"))
  end

  def board = @board ||= Dashboard::Board.new

  # `8 evolutivos activos · 2 en curso · 2 ciclo QA · 5 esperan humano`
  def shell_summary
    summary = board.summary

    safe_join([
      "#{summary.active} #{'evolutivo'.pluralize(summary.active)} #{'activo'.pluralize(summary.active)} · ",
      tag.span("#{summary.in_progress} en curso", class: "text-glyph-done"),
      " · ",
      tag.span("#{summary.qa_cycle} ciclo QA", class: "text-glyph-fail"),
      " · ",
      tag.span("#{summary.awaiting_human} esperan humano", class: "text-antique-gold")
    ])
  end

  # `ap@identia`, como la maqueta. Iniciales y no el correo entero: la barra de
  # título es de 38 px y lo que importa ahí es de quién es la sesión, no su
  # dirección exacta.
  def current_user_handle
    initials = current_user_initials

    initials.present? ? "#{initials.downcase}@identia" : "—"
  end

  def current_user_initials
    source = Current.user&.name.presence ||
             Current.user&.email_address.to_s.split("@").first.to_s

    source.split(/[\s._-]+/).first(2).filter_map { |part| part[0]&.upcase }.join
  end
end
