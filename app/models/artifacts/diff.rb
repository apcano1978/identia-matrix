# frozen_string_literal: true

module Artifacts
  # El diff entre dos versiones de un artefacto, línea a línea.
  #
  # Escrito a mano y no con una gema. El repo ya construye su kit de componentes
  # sin dependencias, y meter una gema nueva dentro de la historia de la
  # inmutabilidad —donde lo que importa es poder auditar exactamente qué se
  # compara— es peor negocio que cuarenta líneas con test.
  #
  # Compara CUERPOS, no documentos: el front-matter cambia en cada versión por
  # construcción —`version`, `checksum`, `produced_at`— y ese ruido taparía la
  # señal, que es qué cambió en el texto.
  module Diff
    Line = Data.define(:op, :before, :after, :text) do
      def added? = op == :add
      def deleted? = op == :del
      def kept? = op == :keep
    end

    # Por encima de esto no se calcula la subsecuencia común: la tabla de LCS es
    # cuadrática y un cuerpo patológico colgaría la petición. Se degrada a
    # «reemplazado entero», que sigue siendo cierto.
    MAX_LINES = 4_000

    module_function

    def call(before, after)
      old_lines = (before || "").lines.map(&:chomp)
      new_lines = (after || "").lines.map(&:chomp)

      return replaced(old_lines, new_lines) if too_long?(old_lines, new_lines)

      walk(old_lines, new_lines, lengths(old_lines, new_lines))
    end

    def too_long?(old_lines, new_lines)
      old_lines.size > MAX_LINES || new_lines.size > MAX_LINES
    end

    def replaced(old_lines, new_lines)
      deleted = old_lines.each_with_index.map do |text, index|
        Line.new(op: :del, before: index + 1, after: nil, text: text)
      end
      added = new_lines.each_with_index.map do |text, index|
        Line.new(op: :add, before: nil, after: index + 1, text: text)
      end

      deleted + added
    end

    # La tabla clásica de longitudes de subsecuencia común más larga.
    def lengths(old_lines, new_lines)
      table = Array.new(old_lines.size + 1) { Array.new(new_lines.size + 1, 0) }

      old_lines.each_index.reverse_each do |i|
        new_lines.each_index.reverse_each do |j|
          table[i][j] = if old_lines[i] == new_lines[j]
            table[i + 1][j + 1] + 1
          else
            [ table[i + 1][j], table[i][j + 1] ].max
          end
        end
      end

      table
    end

    # Recorre la tabla desde el principio decidiendo, en cada paso, si la línea
    # se conserva, se borra o se añade.
    def walk(old_lines, new_lines, table)
      lines = []
      i = 0
      j = 0

      while i < old_lines.size && j < new_lines.size
        if old_lines[i] == new_lines[j]
          lines << Line.new(op: :keep, before: i + 1, after: j + 1, text: old_lines[i])
          i += 1
          j += 1
        elsif table[i + 1][j] >= table[i][j + 1]
          lines << Line.new(op: :del, before: i + 1, after: nil, text: old_lines[i])
          i += 1
        else
          lines << Line.new(op: :add, before: nil, after: j + 1, text: new_lines[j])
          j += 1
        end
      end

      while i < old_lines.size
        lines << Line.new(op: :del, before: i + 1, after: nil, text: old_lines[i])
        i += 1
      end

      while j < new_lines.size
        lines << Line.new(op: :add, before: nil, after: j + 1, text: new_lines[j])
        j += 1
      end

      lines
    end
  end
end
