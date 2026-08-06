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

    def to_s = raw
  end
end
