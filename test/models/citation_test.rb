require "test_helper"

class CitationTest < ActiveSupport::TestCase
  test "el nivel se deriva del tipo, no se guarda" do
    assert_not_includes Citation.column_names, "level"

    doc = Citation.from_raw("[src:doc/acta-precios#p2]", citable: build_artifact)

    assert_predicate doc, :origin?
    assert_equal :origin, doc.level
  end

  # INVARIANTE 4 · ninguna afirmación sobre el código sin repositorio.
  test "una cita de código sin repositorio no es válida" do
    citation = Citation.new(
      citable: build_artifact, raw: "[src:code/identia-platform:app/x.rb]",
      source_kind: :code, locator: "app/x.rb")

    assert_not citation.valid?
    assert_match "obligatorio", citation.errors[:repository].to_sentence
  end

  test "una cita de verificación tampoco puede ir sin repositorio" do
    citation = Citation.new(
      citable: build_artifact, raw: "[src:verify/identia-platform:test/x_test.rb]",
      source_kind: :verify, locator: "test/x_test.rb")

    assert_not citation.valid?
  end

  test "una cita de documento no necesita repositorio" do
    citation = Citation.from_raw("[src:doc/acta-precios]", citable: build_artifact)

    assert_predicate citation, :valid?
  end

  test "un texto que la gramática de F0 rechaza no llega a la base de datos" do
    citation = Citation.new(citable: build_artifact, raw: "[src:doc/Mayúsculas]",
                            source_kind: :doc, locator: "Mayúsculas")

    assert_not citation.valid?
    assert_match "gramática", citation.errors[:raw].to_sentence
  end

  test "from_raw reparte los trozos según la gramática, no a ojo" do
    citation = Citation.from_raw(
      "[src:code/identia-platform:app/models/lead.rb#L40@a1b2c3d]",
      citable: build_artifact, repository: build_repository)

    assert_equal "code", citation.source_kind
    assert_equal "app/models/lead.rb", citation.locator
    assert_equal "L40", citation.fragment
    assert_equal "a1b2c3d", citation.commit_sha
  end
end
