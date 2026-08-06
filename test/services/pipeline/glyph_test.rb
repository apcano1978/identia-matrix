require "test_helper"

class Pipeline::GlyphTest < ActiveSupport::TestCase
  test "los estados que no dependen de la etapa" do
    assert_equal "○", glyph(:neo, :pending)
    assert_equal "●", glyph(:neo, :done)
    assert_equal "✕", glyph(:neo, :failed)
    assert_equal "⊘", glyph(:neo, :escalated)
  end

  test "activo es un rombo salvo en las tres esperas propias" do
    assert_equal "◆", glyph(:neo, :active)
    assert_equal "▣", glyph(:gate_1, :active)
    assert_equal "▤", glyph(:gate_2, :active)
    assert_equal "»", glyph(:claude_code, :active)
  end

  # Tercera inconsistencia de la maqueta: pinta » en nodos completos de unos
  # evolutivos y ● en otros igual de completos. Manda la regla, no la maqueta.
  test "claude code terminado es un punto, no una comilla" do
    assert_equal "●", glyph(:claude_code, :done)
  end

  test "el glifo no se guarda en ninguna tabla" do
    assert_not_includes StageEntry.column_names, "glyph"
    assert_not_includes Initiative.column_names, "glyph"
  end

  test "la tira tiene doce y las etapas sin fila salen pendientes" do
    initiative = place(build_initiative, :tank)
    Pipeline::Advance.call(initiative: initiative)

    strip = Pipeline::Glyph.strip(initiative)

    assert_equal 12, strip.size
    assert_equal "●", strip[Initiative::STAGES.index("tank")]
    assert_equal "◆", strip[Initiative::STAGES.index("neo")]
    assert_equal "○", strip.last
  end

  test "la tira enseña la última vuelta de cada etapa, no todas" do
    initiative = place(build_initiative, :morfeo)
    Pipeline::SendBack.call(initiative: initiative, to: :neo)

    strip = Pipeline::Glyph.strip(initiative)

    assert_equal "✕", strip[Initiative::STAGES.index("morfeo")]
    assert_equal "◆", strip[Initiative::STAGES.index("neo")]
  end

  private
    def glyph(stage, status) = Pipeline::Glyph.for(stage: stage, status: status)
end
