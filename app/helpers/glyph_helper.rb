# frozen_string_literal: true

# El vocabulario de glifos, en un solo sitio. **La vista nunca elige un símbolo**:
# pide el glifo de un estado y recibe el símbolo con su color.
#
# Hay TRES alfabetos y no uno, aunque compartan tinta:
#
#   stage_glyph    ● ◆ ▣ ▤ » ✕ ⊘ ○   el pipeline · deriva de Pipeline::Glyph
#   verdict_glyph  ✓ ✕ ? ⊗           el dictamen · deriva de Verdict::GLYPHS
#   check_glyph    ● ✕ ○             las comprobaciones de entorno de F1
#
# Forzar los tres por una firma común habría obligado a un `case` sobre qué
# clase de cosa se está pintando, que es exactamente la decisión que la vista no
# debe tomar.
module GlyphHelper
  # El color depende del SÍMBOLO, no de la etapa: un ✕ es terracota lo pinte
  # quien lo pinte. Así el mapa tiene once entradas y no doce por cinco.
  GLYPH_COLORS = {
    "●" => "text-glyph-done",
    "»" => "text-glyph-done",
    "◆" => "text-glyph-active",
    "▣" => "text-glyph-active",
    "▤" => "text-glyph-gate2",
    "✕" => "text-glyph-fail",
    "⊘" => "text-glyph-fail",
    "○" => "text-glyph-pending",
    "✓" => "text-glyph-done",
    "?" => "text-glyph-active",
    "⊗" => "text-glyph-unsupported",
    "↺" => "text-glyph-fail"
  }.freeze

  CHECK_GLYPHS = { ok: "●", failed: "✕", pending: "○" }.freeze

  # Los once glifos de la maqueta, en su orden. Sin la leyenda la interfaz es un
  # jeroglífico para quien llega nuevo. `↺` no es un estado de etapa: marca el
  # arco de ciclo QA de la ficha de evolutivo, y está aquí porque la leyenda
  # explica el vocabulario entero, no solo lo que se ve en esta pantalla.
  LEGEND = [
    [ "●", "hecho" ], [ "◆", "en curso" ], [ "▣", "gate 1" ], [ "▤", "gate 2" ],
    [ "»", "ejecutando" ], [ "✕", "incumplido" ], [ "?", "no concluyente" ],
    [ "↺", "ciclo QA" ], [ "⊘", "escalado" ], [ "⊗", "no soportado aún" ],
    [ "○", "pendiente" ]
  ].freeze

  def stage_glyph(stage, status, **options)
    glyph_tag(Pipeline::Glyph.for(stage: stage, status: status), **options)
  end

  def verdict_glyph(verdict, **options)
    glyph_tag(Verdict::GLYPHS.fetch(verdict.to_s), **options)
  end

  def check_glyph(status, **options)
    glyph_tag(CHECK_GLYPHS.fetch(status.to_sym), **options)
  end

  # La tira de doce. Aparece en cuatro pantallas, así que vive aquí y no en un
  # parcial por pantalla.
  def stage_strip(initiative, size: "text-t11")
    tag.span(class: "flex items-center gap-[3px]", data: { strip: initiative.code }) do
      safe_join(Pipeline::Glyph.strip(initiative).map { |s| glyph_tag(s, size: size) })
    end
  end

  def glyph_legend
    tag.div(class: "flex flex-wrap items-center gap-x-4 gap-y-1 text-t95 text-terminal-muted") do
      safe_join(LEGEND.map do |symbol, meaning|
        tag.span(class: "flex items-center gap-1.5") do
          safe_join([ glyph_tag(symbol, size: "text-t10"), meaning ])
        end
      end)
    end
  end

  private
    def glyph_tag(symbol, size: "text-t13", title: nil)
      colour = GLYPH_COLORS.fetch(symbol, "text-terminal-muted")

      tag.span(symbol, class: "#{size} leading-none #{colour}", title: title)
    end
end
