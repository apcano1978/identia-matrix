require "test_helper"

# INVARIANTE 8 · Gana el ORIGEN. Siempre.
#
# Si el acta dice una cosa y la spec dice otra, la spec está mal. No es una
# decisión que el sistema ofrezca: no hay forma de resolverlo al revés.
class TheOriginWinsTest < ActiveSupport::TestCase
  test "resolver marca para revisión el artefacto que hizo la afirmación derivada" do
    conflict = conflict_between(derived: "[src:dod/dod-031#c3]",
                                origin: "[src:meet/2026-05-02@22:40]")

    conflict.resolve!

    assert_equal CitationConflict::ORIGIN_WINS, conflict.resolution
    assert_equal conflict.derived_citation.citable, conflict.flagged_artifact
  end

  test "y no hay forma de resolverlo al revés" do
    resolvers = CitationConflict.instance_methods(false).grep(/\Aresolve!?\z/)

    assert_equal [ :resolve! ], resolvers
  end

  test "el conflicto no puede construirse con los niveles cambiados" do
    invalid = CitationConflict.new(
      derived_citation: citation("[src:meet/2026-05-02@22:40]"),
      origin_citation: citation("[src:dod/dod-031#c3]"),
      detected_at: Time.current)

    assert_not invalid.valid?
    assert_includes invalid.errors.attribute_names, :derived_citation
    assert_includes invalid.errors.attribute_names, :origin_citation
  end

  # La fila de un artefacto no se toca ni para metadatos: la marca de revisión
  # se DERIVA del conflicto, no vive en una columna suya.
  test "marcar no escribe en el artefacto" do
    assert_not_includes Artifact.column_names, "flagged_for_review"
    assert_not_includes Artifact.column_names, "needs_review"

    conflict = conflict_between(derived: "[src:dod/dod-031#c3]",
                                origin: "[src:doc/acta-precios#p2]")
    artifact = conflict.derived_citation.citable

    assert_no_changes -> { artifact.reload.updated_at } do
      conflict.resolve!
    end
  end

  test "el nivel de una cita se deriva del tipo, no se guarda" do
    assert_not_includes Citation.column_names, "level"
    assert_equal :origin, citation("[src:doc/acta-precios#p2]").level
    assert_equal :derived, citation("[src:dod/dod-031#c3]").level
  end

  private
    def artifact = @artifact ||= build_artifact

    def citation(raw)
      artifact.citations.find_by(raw: raw) ||
        Citation.from_raw(raw, citable: artifact).tap(&:save!)
    end

    def conflict_between(derived:, origin:)
      CitationConflict.create!(derived_citation: citation(derived),
                               origin_citation: citation(origin),
                               detected_at: Time.current)
    end
end
