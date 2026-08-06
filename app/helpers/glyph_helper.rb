# frozen_string_literal: true

# El vocabulario de glifos de matrix, en un solo sitio.
#
# La vista nunca elige un símbolo ni un color: pide el glifo de un estado. En F3
# esto crecerá para cubrir las doce etapas del pipeline; aquí solo hacen falta
# los tres estados de la página de diagnóstico.
module GlyphHelper
  GLYPHS = {
    ok:      { symbol: "●", color: "text-glyph-done" },
    failed:  { symbol: "✕", color: "text-glyph-fail" },
    pending: { symbol: "○", color: "text-glyph-pending" }
  }.freeze

  def glyph(status)
    entry = GLYPHS.fetch(status.to_sym)
    tag.span(entry[:symbol], class: entry[:color])
  end
end
