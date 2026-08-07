# frozen_string_literal: true

module Citations
  # Una cita ya parseada. Objeto de valor: sin estado, sin persistencia.
  #
  # La tabla `citations` de F2 se construirá a partir de esto, pero el parseo en
  # sí no necesita base de datos — y así se puede validar la gramática desde un
  # test unitario, sin cargar el dominio entero.
  Reference = Data.define(:raw, :kind, :repository, :locator, :anchor, :commit_sha, :clock, :author, :meeting_slug) do
    def level = Grammar.level(kind)

    def origin?  = Grammar.origin?(kind)
    def derived? = Grammar.derived?(kind)

    # El glifo con el que la interfaz marca el nivel: ◆ origen, ↳ derivado.
    def glyph = origin? ? "◆" : "↳"

    # Las citas de código se anclan a un commit. Sin él, la cita afirma algo
    # sobre "el código" sin decir cuál — que es justo lo que el invariante 4
    # prohíbe.
    def pinned? = commit_sha.present?

    # La cita sin su envoltorio, para enseñarla en una tabla estrecha:
    #
    #   [src:doc/acta-precios#p2]  →  doc/acta-precios#p2
    #
    # Se DERIVA de `raw`, quitándole los extremos. No se recompone a partir de
    # las piezas: recomponer es cómo aparecen las divergencias, y la maqueta ya
    # trae dos —`trinity/pkg-045#deploy` en vez de `pkg/…`, y `spec-031#§7` sin
    # su prefijo—. Con una sola cadena en el sistema no hay forma de discrepar.
    def compact = raw.delete_prefix("[src:").delete_suffix("]")

    def to_s = raw
  end
end
