# frozen_string_literal: true

# Los documentos subidos, en pantalla.
module ProjectDocumentsHelper
  State = Data.define(:glyph, :label, :tone)

  # Los TRES estados salen de las columnas, no de un enum paralelo que pueda
  # discrepar de ellas:
  #
  #   sin `extracted_at`      se está extrayendo
  #   con cuerpo              citable
  #   con error               sin cuerpo extraído, y la fila dice por qué
  #
  # El glifo del citable es el mismo `●` que el de una etapa hecha, y el de
  # extrayendo el `◆` de en curso: el idioma visual del sistema ya dice
  # «terminado» y «en marcha», y no hace falta inventar otro.
  def document_state(document)
    return State.new(glyph: "◆", label: "extrayendo texto",
                     tone: "text-glyph-active") unless document.extracted?
    return State.new(glyph: "●", label: "citable",
                     tone: "text-glyph-done") if document.citable?

    State.new(glyph: "○", label: "sin cuerpo extraído",
              tone: "text-terminal-fg-4")
  end

  # El tamaño del fichero, que es lo que el rediseño pone al lado del estado
  # —«extrayendo texto · 8 kB»—: sale del blob, no de una columna.
  def document_size(document)
    return "—" unless document.file.attached?

    number_to_human_size(document.file.blob.byte_size)
  end
end
