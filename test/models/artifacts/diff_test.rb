# frozen_string_literal: true

require "test_helper"

class Artifacts::DiffTest < ActiveSupport::TestCase
  test "dos textos idénticos no tienen ningún cambio" do
    lines = diff("a\nb\nc\n", "a\nb\nc\n")

    assert lines.all?(&:kept?)
    assert_equal %w[a b c], lines.map(&:text)
  end

  test "una línea añadida se marca, y el resto se conserva" do
    lines = diff("a\nc\n", "a\nb\nc\n")

    assert_equal %i[keep add keep], lines.map(&:op)
    assert_equal "b", lines.find(&:added?).text
  end

  test "una línea borrada se marca" do
    lines = diff("a\nb\nc\n", "a\nc\n")

    assert_equal %i[keep del keep], lines.map(&:op)
    assert_equal "b", lines.find(&:deleted?).text
  end

  # Cambiar una línea es borrar la vieja y añadir la nueva: el diff es por
  # líneas, no por caracteres.
  test "una línea cambiada es un borrado y un alta" do
    lines = diff("a\nviejo\nc\n", "a\nnuevo\nc\n")

    assert_equal [ "viejo" ], lines.select(&:deleted?).map(&:text)
    assert_equal [ "nuevo" ], lines.select(&:added?).map(&:text)
  end

  test "la numeración es la de cada lado, y no coincide cuando hay cambios" do
    lines = diff("a\nc\n", "a\nb\nc\n")

    added = lines.find(&:added?)
    assert_nil added.before, "una línea añadida no existe en el original"
    assert_equal 2, added.after

    last = lines.last
    assert_equal 2, last.before
    assert_equal 3, last.after
  end

  test "de vacío a algo es todo altas, y al revés todo bajas" do
    assert diff("", "a\nb\n").all?(&:added?)
    assert diff("a\nb\n", "").all?(&:deleted?)
    assert_empty diff("", "")
  end

  test "nil se trata como vacío" do
    assert diff(nil, "a\n").all?(&:added?)
    assert diff("a\n", nil).all?(&:deleted?)
  end

  # La tabla de LCS es cuadrática: sin este corte un cuerpo patológico cuelga la
  # petición. Degradar a «reemplazado entero» sigue siendo cierto.
  test "por encima del límite se degrada a reemplazo entero, sin colgarse" do
    largo = Array.new(Artifacts::Diff::MAX_LINES + 1) { |i| "línea #{i}" }.join("\n")
    lines = diff(largo, "#{largo}\nuna más")

    assert lines.none?(&:kept?), "no calcula la subsecuencia común"
    assert lines.any?(&:deleted?)
    assert lines.any?(&:added?)
  end

  # El caso real de la fase: entre dod-031 v1 y v2 se añadió el criterio c0.
  test "el caso de dod-031: se añadió una sección entera" do
    v1 = "# DoD\n\n## c1 · Precio\n\nAlgo.\n"
    v2 = "# DoD\n\n## c0 · Compatibilidad\n\nOtra cosa.\n\n## c1 · Precio\n\nAlgo.\n"

    added = diff(v1, v2).select(&:added?).map(&:text)

    assert_includes added, "## c0 · Compatibilidad"
    assert_includes added, "Otra cosa."
    assert_empty diff(v1, v2).select(&:deleted?),
                 "añadir una sección no borra nada"
  end

  private
    def diff(before, after) = Artifacts::Diff.call(before, after)
end
