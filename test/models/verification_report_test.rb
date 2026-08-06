require "test_helper"

# INVARIANTE 7 · solo ✕ consume ciclo de QA.
#
# Confundir `inconclusive` o `unsupported` con `unmet` haría que NEO escribiera
# specs para arreglar bugs que no existen: el error más caro que el sistema
# puede cometer.
class VerificationReportTest < ActiveSupport::TestCase
  test "un informe con un solo ✕ consume ciclo" do
    assert_predicate report_with(:met, :unmet, :inconclusive), :consumes_cycle?
  end

  test "un informe de solo ? no consume ciclo" do
    assert_not report_with(:inconclusive, :inconclusive).consumes_cycle?
  end

  test "un informe de solo ⊗ no consume ciclo" do
    assert_not report_with(:unsupported, :unsupported).consumes_cycle?
  end

  test "un informe conforme no consume ciclo" do
    assert_not report_with(:met, :met, :unsupported).consumes_cycle?
  end

  test "no hay tabla de ciclos: el dato se deriva del informe" do
    assert_not_includes ActiveRecord::Base.connection.tables, "qa_cycles"
  end

  test "el semáforo de CI se compone de todos los checks, no solo de la suite" do
    report = report_with(:met)
    repositories = 2.times.map do |i|
      build_repository(client: report.initiative.platform_client, name: "repo-#{i}")
    end
    CiCheck.create!(verification_report: report, repository: repositories.first,
                    commit_sha: "a1b2c3d", status: :green)

    assert_equal "green", report.reload.ci_status

    CiCheck.create!(verification_report: report, repository: repositories.last,
                    commit_sha: "e4f5g6h", status: :red)

    assert_equal "red", report.reload.ci_status
  end

  test "sin CI el semáforo dice que no se sabe, no que está verde" do
    assert_equal "unavailable", report_with(:met).ci_status
  end

  private
    def report_with(*results)
      dod = build_dod
      report = build_report(dod: dod)
      results.each_with_index do |result, index|
        Verdict.create!(verification_report: report,
                        dod_criterion: build_criterion(dod: dod, key: "c#{index}"),
                        result: result)
      end
      report.reload
    end
end
