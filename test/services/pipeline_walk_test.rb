require "test_helper"

# El recorrido no es un test de unidad: es la prueba de que las piezas de F2
# encajan. Cada variante fuerza una bifurcación y lo que se comprueba es qué
# contador subió y cuál no.
class PipelineWalkTest < ActiveSupport::TestCase
  setup { DesignSeed.call }

  test "el recorrido feliz encadena las doce etapas y publica" do
    initiative = walk("happy")

    assert_predicate initiative, :at_publication?
    assert_predicate initiative, :status_done?
    assert_equal 12, Pipeline::Glyph.strip(initiative).count("●")
    assert_equal 0, initiative.qa_cycles_consumed
  end

  test "y deja los artefactos en el bucket, con sus citas" do
    initiative = walk("happy")

    assert_equal %w[dossier spec dod pkg verify close].sort,
                 initiative.artifacts.map(&:kind).uniq.sort
    assert initiative.artifacts.all? { |a| a.body.attached? }
    assert_predicate initiative.artifacts.sum { |a| a.citations.count }, :positive?
  end

  test "un ✕ vuelve a NEO y sube los DOS contadores" do
    initiative = walk("fail-once")

    assert_equal 1, initiative.qa_cycles_consumed
    assert_operator initiative.iteration, :>, 1
    assert_predicate initiative, :at_publication?
  end

  test "un rechazo en GATE 2 sube `iteration` pero NO el de QA" do
    initiative = walk("reject-gate-2")

    assert_equal 0, initiative.qa_cycles_consumed
    assert_operator initiative.iteration, :>, 1
    assert_equal 1, initiative.gate_validations.decision_rejected.count
  end

  test "GATE 1 devuelve a TRINITY con una nota humana de nivel ORIGEN" do
    initiative = walk("return-to-trinity")

    note = initiative.human_notes.sole
    # Una nota humana pesa lo mismo que un acta: es fuente de ORIGEN.
    assert Citations::Grammar.origin?("note")
    assert_match(/\A\[src:note\//, note.citation)
    assert_equal 0, initiative.qa_cycles_consumed
    # Volvió a TRINITY, no a NEO: lo que estaba mal era el paquete.
    assert_equal 2, initiative.stage_entries.where(stage: :trinity).count
  end

  test "dos ✕ seguidos detienen con escalada, sin subir a tres" do
    initiative = walk("exhaust")

    assert_predicate initiative, :status_escalated?
    assert_equal Initiative::MAX_QA_CYCLES, initiative.qa_cycles_consumed
    assert_equal "qa_cycles_exhausted", initiative.open_escalation.reason
  end

  test "tres ? escalan SIN consumir ciclo" do
    initiative = walk("inconclusive")

    assert_predicate initiative, :status_escalated?
    assert_equal 0, initiative.qa_cycles_consumed
    assert_equal "inconclusive_environment", initiative.open_escalation.reason
  end

  test "una variante inventada no se recorre a medias" do
    assert_raises(ArgumentError) { walk("optimista") }
  end

  test "el recorrido usa los servicios de verdad, no atajos" do
    source = Rails.root.join("lib/pipeline_walk.rb").read

    assert_match "Pipeline::Advance.call", source
    assert_match "Pipeline::SendBack.call", source
    assert_match "Pipeline::Escalate.call", source
    assert_no_match(/update_column/, source)
  end

  private
    def walk(variant)
      PipelineWalk.call(code: "ev-#{700 + variant.sum % 90}",
                        variant: variant).initiative
    end
end
