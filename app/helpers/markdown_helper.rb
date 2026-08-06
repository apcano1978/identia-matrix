# frozen_string_literal: true

# El cuerpo de un artefacto, renderizado.
module MarkdownHelper
  # `unsafe: false` es el defecto de commonmarker y se declara igualmente: el
  # markdown de un artefacto lo escribe un MODELO DE LENGUAJE, y dejar pasar
  # HTML crudo de ahí sería inyección con pasos extra.
  OPTIONS = {
    render: { unsafe: false, hardbreaks: false },
    extension: { table: true, strikethrough: true, autolink: false }
  }.freeze

  def markdown(text)
    return tag.p("Sin cuerpo.", class: "text-terminal-disabled") if text.blank?

    tag.div(Commonmarker.to_html(text, options: OPTIONS).html_safe,
            class: "markdown-body")
  end
end
