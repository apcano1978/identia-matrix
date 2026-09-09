# frozen_string_literal: true

# La indexación de un repositorio, en pantalla (F12 · B6).
module RepositoriesHelper
  State = Data.define(:glyph, :label, :tone)

  # Los TRES estados salen de las columnas, no de un enum paralelo que pueda
  # discrepar de ellas. Es el mismo patrón que `document_state` en B2:
  #
  #   con `last_synced_at`   leído · N ficheros
  #   con `indexing_error`   el motivo, tal cual
  #   ninguno de los dos     en cola de indexación
  #
  # ⚠ SIN FRACCIÓN NI BARRA, y es una divergencia deliberada de la maqueta. El
  # rediseño pinta «1.204 de 3.900 ficheros · 25m», y ese número **no existe**:
  # contar ficheros es UNA llamada al árbol del repositorio, no un recorrido con
  # progreso. Inventar la fracción sería exactamente lo que estas pantallas
  # existen para no hacer.
  def repository_state(repository)
    if repository.last_synced_at.present?
      return State.new(glyph: "●",
                       label: "#{number_with_delimiter(repository.files_count.to_i)} ficheros",
                       tone: "text-glyph-done")
    end
    if repository.indexing_error.present?
      return State.new(glyph: "○", label: repository.indexing_error,
                       tone: "text-glyph-fail")
    end

    State.new(glyph: "◆", label: "en cola de indexación", tone: "text-glyph-active")
  end

  # Y el ANCLAJE, que es otra pregunta: «con qué commit trabaja ESTE evolutivo».
  # Un repositorio legible puede estar sin anclar para un evolutivo concreto —un
  # 502 justo entonces— y por eso el motivo se guarda en las dos filas.
  #
  # Sin `pinned_sha`, `Runtime::Request` manda el material sin ese repositorio y
  # el agente trabajaría sin haberlo leído. Decir por qué es la diferencia entre
  # eso y lo que P23 describía: «nada avisa».
  def pinned_state(link)
    return State.new(glyph: "●", label: link.pinned_sha, tone: "text-antique-gold") if link.pinned?

    motivo = link.indexing_error.presence || link.repository.indexing_error.presence
    return State.new(glyph: "○", label: motivo, tone: "text-glyph-fail") if motivo

    State.new(glyph: "◆", label: "en cola", tone: "text-glyph-active")
  end
end
