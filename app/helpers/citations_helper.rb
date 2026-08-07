# Cómo se pinta una cita. Un solo sitio, porque la maqueta demuestra lo que
# pasa cuando hay varios: en dos de las siete filas de la columna TRAZA se salta
# su propia gramática —`↳ trinity/pkg-045#deploy` en vez de `pkg/…`, y
# `↳ spec-031#§7` sin prefijo— y las otras cinco no.
#
# Los chips aparecen en cuatro sitios: el cuerpo de los artefactos, la columna
# TRAZA del DoD, las citas de cada paso de la guía y el bloque de evidencia del
# informe. Los tres últimos son F6; el helper se escribe aquí para que no acabe
# habiendo dos.
module CitationsHelper
  # El tono sale del NIVEL y del tipo, nunca de un `case` en la vista. La
  # maqueta pinta el contador ◆ ORIGEN y el extracto de documento en verde; la
  # guía asigna verde solo al código, porque el verde significa «esto está en
  # un repositorio, con su commit» y un acta no lo está. Manda la guía.
  def citation_tone(citation)
    return :derived if citation.derived?

    citation.kind_code? ? :origin_code : :origin_doc
  end

  # La cita en formato compacto, con su glifo de nivel delante:
  #
  #   ◆ doc/acta-precios#p2
  #   ↳ pkg/pkg-045#deploy
  def citation_compact(citation)
    "#{citation.glyph} #{citation.compact}"
  end

  def citation_chip(citation, **options)
    status_chip(citation.compact, tone: citation_tone(citation),
                                  glyph: citation.glyph, **options)
  end

  # El rótulo del nivel, para los contadores del panel: `◆ ORIGEN 9`.
  def citation_level_label(level)
    level.to_sym == :origin ? "◆ ORIGEN" : "↳ DERIVADO"
  end

  # El extracto de una fuente con la frase citada resaltada.
  #
  # Sin cuerpo no hay extracto: el bloque se omite entero en vez de enseñar un
  # hueco con la cita dentro. Y sin frase declarada, el párrafo va sin marca —
  # adivinarla resaltaría lo que no era.
  def citation_excerpt(citation)
    body = citation.target.try(:body)
    return nil if body.blank?

    return tag.span(body) if citation.quote.blank?
    return tag.span(body) unless body.include?(citation.quote)

    before, after = body.split(citation.quote, 2)
    safe_join([ before, tag.mark(citation.quote,
                                 class: "bg-cite-fill-doc text-terminal-fg"),
                after ])
  end
end
