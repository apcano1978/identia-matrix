# frozen_string_literal: true

# El kit de componentes. Helpers y parciales, sin gema: es la convención de
# identia-platform, y traer ViewComponent solo para ocho piezas no compensa
# introducir una dependencia y un patrón nuevos en el workspace.
module UiHelper
  # Pasado este umbral, la edad se pinta en terracota. Dos días es lo que tarda
  # una espera en dejar de ser normal: el dashboard existe para que eso se vea
  # sin leer la cifra.
  STALE_AFTER = 48.hours

  # `25m`, `2h`, `3d`, `12 abr`. La forma corta mientras la espera se cuenta en
  # días; a partir de ahí, la fecha — porque «47d» no le dice nada a nadie.
  def age(from, stale_after: STALE_AFTER)
    return tag.span("—", class: "text-terminal-muted") if from.blank?

    elapsed = Time.current - from
    colour = elapsed > stale_after ? "text-glyph-fail" : "text-terminal-fg-4"

    tag.span(age_label(from, elapsed), class: "text-t105 #{colour}")
  end

  def age_label(from, elapsed)
    case elapsed
    when ...1.hour then "#{(elapsed / 60).floor}m"
    when ...1.day  then "#{(elapsed / 3600).floor}h"
    when ...7.days then "#{(elapsed / 86_400).floor}d"
    else I18n.l(from.to_date, format: :short)
    end
  end

  CHIP_TONES = {
    gold: "text-antique-gold border-terminal-border-gold",
    gate2: "text-glyph-gate2 border-terminal-border-strong",
    fail: "text-glyph-fail border-terminal-border-fail",
    done: "text-glyph-done border-terminal-border-strong",
    muted: "text-terminal-fg-3 border-terminal-border",

    # Los tres niveles de procedencia (F4). Las cadenas van COMPLETAS y
    # literales: Tailwind 4 solo genera el CSS de las clases que ve escritas,
    # y una compuesta por trozos en Ruby no la ve nadie.
    origin_doc: "text-antique-gold border-cite-origin-doc bg-cite-fill-doc",
    origin_code: "text-glyph-done border-cite-origin-code bg-cite-fill-code",
    derived: "text-terminal-fg-4 border-dashed border-cite-derived"
  }.freeze

  def status_chip(text, tone: :muted, glyph: nil)
    tag.span(class: "inline-flex items-center gap-1.5 border px-2 py-[2px] " \
                    "text-t10 #{CHIP_TONES.fetch(tone)}") do
      safe_join([ glyph, text ].compact)
    end
  end

  # El chip de etapa de un evolutivo: el glifo y el rótulo salen del mismo sitio,
  # así que no pueden discrepar.
  def stage_chip(initiative)
    status = initiative.current_stage_status

    status_chip(stage_label(initiative.current_stage),
                tone: chip_tone_for(initiative),
                glyph: stage_glyph(initiative.current_stage, status, size: "text-t11"))
  end

  # El tono tiñe el rótulo y la regla a la vez: son la misma señal, y separarlos
  # deja títulos de un color sobre reglas de otro.
  HEADER_TONES = {
    gold: [ "text-antique-gold", "bg-[rgba(196,155,94,.28)]" ],
    gate2: [ "text-glyph-gate2", "bg-[rgba(221,213,191,.22)]" ],
    fail: [ "text-glyph-fail", "bg-[rgba(201,128,112,.28)]" ],
    muted: [ "text-terminal-fg-3", "bg-terminal-border" ]
  }.freeze

  # `## TÍTULO (n) ─────────── glosa`. La regla se estira; la glosa se ancla a la
  # derecha y explica de qué va la sección en minúsculas.
  def section_header(title, count: nil, gloss: nil, tone: :gold)
    colour, rule = HEADER_TONES.fetch(tone)

    tag.div(class: "flex items-center gap-2.5 mt-2") do
      safe_join([
        tag.span("## #{title}", class: "section-title #{colour}"),
        (tag.span("(#{count})", class: "text-t11 text-terminal-fg-3") if count),
        tag.div(class: "flex-1 h-px #{rule}"),
        (tag.span(gloss, class: "text-t10 text-terminal-fg-3") if gloss)
      ].compact)
    end
  end

  # Panel lateral de ancho fijo. El ancho lo fija cada pantalla —§1.1 los mide
  # uno a uno— y el scroll vive DENTRO del panel, nunca en la página.
  def side_panel(width:, &block)
    tag.aside(class: "flex-none bg-terminal-sunken border-l border-terminal-border " \
                     "overflow-y-auto",
              style: "width:#{width}px", &block)
  end

  def panel_block(title, &block)
    tag.section(class: "px-3.5 py-3 border-b border-terminal-border") do
      safe_join([ tag.h2(title, class: "eyebrow text-terminal-muted mb-2.5"),
                  capture(&block) ])
    end
  end

  STAGE_LABELS = {
    "need" => "necesidad", "tank" => "TANK", "neo" => "NEO",
    "seraph_dod" => "SERAPH · DoD", "morfeo" => "MORFEO", "trinity" => "TRINITY",
    "gate_1" => "GATE 1 · FIRMA", "claude_code" => "CLAUDE CODE",
    "seraph_verification" => "SERAPH · verificación",
    "gate_2" => "GATE 2 · VALIDACIÓN", "link" => "LINK",
    "publication" => "publicación"
  }.freeze

  # La cadena decorativa de la barra de comando: los doce en corto y en orden.
  # Es un rótulo distinto del de los nodos —ahí caben «GATE 1 · FIRMA», aquí no—
  # y por eso son dos mapas y no uno truncado.
  STAGE_SHORT = {
    "need" => "necesidad", "tank" => "tank", "neo" => "neo",
    "seraph_dod" => "seraph·dod", "morfeo" => "morfeo", "trinity" => "trinity",
    "gate_1" => "gate1", "claude_code" => "claude code",
    "seraph_verification" => "seraph·verif", "gate_2" => "gate2",
    "link" => "link", "publication" => "pub"
  }.freeze

  def stage_label(stage) = STAGE_LABELS.fetch(stage.to_s)

  def stage_chain = STAGE_SHORT.values.join(" · ")

  Situation = Data.define(:glyph, :label, :colour)

  # Lo que le pasa a un evolutivo, en una línea. NO es su etapa: un evolutivo en
  # `neo` puede estar empezando la spec o volviendo de un ✕, y son cosas
  # distintas para quien mira la lista. La etapa sola no lo distingue; el par
  # (etapa, contadores) sí.
  # `short:` es para las tarjetas, donde no cabe el matiz: la maqueta pone «▤
  # validación» ahí y «▤ espera validación» en la matriz. El motivo de una
  # escalada tampoco cabe en una tarjeta, y truncado no dice nada.
  def situation(initiative, short: false)
    case
    when initiative.status_escalated?
      Situation.new(glyph: "⊘", colour: "text-glyph-fail",
                    label: short ? "escalado" : escalation_label(initiative))
    when initiative.at_publication?
      Situation.new(glyph: "●", colour: "text-glyph-done",
                    label: short ? "cerrado" : closure_label(initiative))
    when initiative.at_gate_1?
      Situation.new(glyph: "▣", colour: "text-antique-gold",
                    label: short ? "firma" : "espera firma")
    when initiative.at_gate_2?
      Situation.new(glyph: "▤", colour: "text-glyph-gate2",
                    label: short ? "validación" : "espera validación")
    when initiative.qa_cycles_consumed.positive?
      Situation.new(glyph: "↺", colour: "text-glyph-fail",
                    label: "ciclo QA #{initiative.qa_cycles_consumed}/#{Initiative::MAX_QA_CYCLES}")
    else
      Situation.new(glyph: "◆", colour: "text-terminal-fg-3",
                    label: short ? "en curso" : STAGE_SHORT.fetch(initiative.current_stage))
    end
  end

  def situation_tag(initiative, size: "text-t105", short: false)
    state = situation(initiative, short: short)

    tag.span("#{state.glyph} #{state.label}", class: "#{size} #{state.colour}")
  end

  private
    def escalation_label(initiative)
      reason = initiative.open_escalation&.reason

      reason.present? ? "escalado · #{reason.tr('_', ' ')}" : "escalado"
    end

    def closure_label(initiative)
      closure = initiative.artifacts.find { |a| a.kind_close? }

      closure.present? ? "cerrado · #{closure.code}" : "cerrado"
    end


    def chip_tone_for(initiative)
      return :fail if initiative.status_escalated? || initiative.status_failed?
      return :gold if initiative.at_gate_1?
      return :gate2 if initiative.at_gate_2?
      return :done if initiative.at_publication?

      :muted
    end
end
