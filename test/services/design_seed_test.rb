require "test_helper"

# El seed existe para MIRARLO: es la maqueta convertida en filas. Estos tests
# comprueban que lo que sale por pantalla es lo que la maqueta enseña.
class DesignSeedTest < ActiveSupport::TestCase
  setup { DesignSeed.call }

  test "sembrar dos veces deja el mismo estado" do
    counts = -> { model_counts }
    before = counts.call

    DesignSeed.call

    assert_equal before, counts.call
  end

  test "se niega a correr en producción" do
    Rails.env.stub(:production?, true) do
      assert_raises(RuntimeError) { DesignSeed.call }
    end
  end

  test "db/seeds.rb no siembra nada" do
    assert_empty Rails.root.join("db/seeds.rb").read.lines
                      .grep_v(/\A\s*(#|\z)/)
  end

  # La comprobación que la guía pide leer, no ejecutar: la matriz evolutivo ×
  # repositorio de vivla, tal como la enseña la ficha de cliente.
  test "la matriz de vivla es la de la maqueta" do
    client = Platform::Client.find_by!(slug: "vivla")
    initiatives = Initiative.where(platform_client: client)

    assert_equal 5, initiatives.count
    assert_equal 3, Repository.where(platform_client: client).count
    assert_equal 2, initiatives.count(&:multi_repo?)
  end

  test "los diez evolutivos están donde la maqueta los deja" do
    expected = {
      "ev-002" => "publication", "ev-009" => "publication",
      "ev-014" => "neo", "ev-019" => "gate_1", "ev-022" => "gate_2",
      "ev-024" => "seraph_verification", "ev-027" => "link",
      "ev-031" => "gate_2", "ev-038" => "tank", "ev-041" => "gate_1"
    }

    assert_equal expected, Initiative.order(:code).pluck(:code, :current_stage).to_h
  end

  test "ev-031 lleva los once criterios, nueve ✓ y dos ⊗" do
    report = VerificationReport.find_by!(code: "verify-031-r2")

    assert_equal 11, report.definition_of_done.dod_criteria.count
    assert_equal({ "met" => 9, "unsupported" => 2 }, report.verdict_counts)
  end

  # Dos ⊗ y ningún ✕: el informe da conforme y NO consume ciclo. Es la
  # diferencia que justifica los cuatro veredictos.
  test "y no consume ciclo pese a tener dos criterios sin verificar" do
    report = VerificationReport.find_by!(code: "verify-031-r2")

    assert_not report.consumes_cycle?
    assert_predicate report, :outcome_conforme?
    assert_equal "green", report.ci_status
    assert_equal 3, report.ci_checks.count
  end

  test "los dos ⊗ redirigen al paso de guía que los cubre" do
    report = VerificationReport.find_by!(code: "verify-031-r2")
    unsupported = report.unsupported_verdicts

    assert_equal %w[c5 c6], unsupported.map { |v| v.dod_criterion.key }.sort
    assert_equal [ 3, 4 ], unsupported.map { |v| v.guide_step.position }.sort
    assert unsupported.none?(&:evidenced?)
  end

  test "la guía tiene cuatro pasos y los dos sin recorrer bloquean GATE 2" do
    guide = TestGuide.find_by!(code: "guia-pruebas-031")

    assert_equal({ total: 4, walked: 2, exempted: 0, pending: 2 },
                 guide.coverage)
    assert_equal [ 3, 4 ], guide.blocking_steps.map(&:position)
    assert_equal 2, guide.guide_steps.count(&:evidence_sole_evidence?)
  end

  test "GATE 1 quedó firmado, con los tres commits y en orden" do
    signature = GateSignature.find_by!(package_hash: WorkPackage
                                         .find_by!(code: "pkg-045").content_hash)

    assert_equal "Antonio Pérez · CTO", signature.identity
    assert_equal %w[pricing-svc booking-core owner-web],
                 signature.commits_in_deploy_order.map { |c| c.repository.name }
    assert_predicate signature, :fully_executed?
    assert_raises(ActiveRecord::ReadOnlyRecord) { signature.destroy }
  end

  test "el conflicto enfrenta una cita derivada con una de origen" do
    conflict = CitationConflict.sole

    assert_predicate conflict.derived_citation, :derived?
    assert_predicate conflict.origin_citation, :origin?
    assert_equal "[src:meet/2026-05-02@22:40]", conflict.origin_citation.raw
  end

  test "los artefactos llevan citas de verdad, parseadas del cuerpo" do
    spec = Artifact.find_by!(code: "spec-031")

    assert_predicate spec.body, :attached?
    assert_predicate spec.citations.count, :positive?
    assert_equal spec.citations.pluck(:raw).sort,
                 Citations::Parse.scan(spec.body_markdown).first
                                 .map(&:raw).uniq.sort
  end

  test "y las de código resuelven contra su repositorio" do
    code_citations = Citation.kind_code

    assert_predicate code_citations.count, :positive?
    assert code_citations.all? { |c| c.repository.present? }
  end

  # ── Los cuatro restos de la maqueta que no se copian ─────────────────────

  test "la spec va por v4 en todas partes" do
    assert_equal 4, Artifact.find_by!(code: "spec-031").version
  end

  test "dod-031#c3 traza a ORIGEN, no a derivada" do
    c3 = DodCriterion.find_by!(key: "c3")

    assert_predicate c3.trace_citation, :origin?
    assert_equal "code", c3.trace_citation.source_kind
  end

  test "claude code terminado es ●, no »" do
    strip = Pipeline::Glyph.strip(Initiative.find_by!(code: "ev-031"))

    assert_equal "●", strip[Initiative::STAGES.index("claude_code")]
  end

  test "y un GATE 1 ya firmado también es ●" do
    strip = Pipeline::Glyph.strip(Initiative.find_by!(code: "ev-031"))

    assert_equal "●", strip[Initiative::STAGES.index("gate_1")]
    # El de un evolutivo que sí espera firma sigue siendo ▣.
    assert_equal "▣", Pipeline::Glyph.strip(Initiative.find_by!(code: "ev-041"))
                                     .fetch(Initiative::STAGES.index("gate_1"))
  end

  private
    def model_counts
      ActiveRecord::Base.connection.tables
                        .reject { |t| t.start_with?("ar_", "schema_") }
                        .to_h { |t| [ t, ActiveRecord::Base.connection
                                           .select_value("select count(*) from #{t}") ] }
    end
end
