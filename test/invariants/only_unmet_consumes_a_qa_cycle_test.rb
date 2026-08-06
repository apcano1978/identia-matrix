require "test_helper"

# INVARIANTE 7 · Solo el ✕ consume ciclo de QA.
#
# Es la pieza que distingue este sistema de un gestor de tareas. Confundir `?`
# o `⊗` con `✕` haría que NEO escribiera specs para arreglar bugs que no
# existen: el error más caro que el sistema puede cometer.
class OnlyUnmetConsumesAQaCycleTest < ActiveSupport::TestCase
  test "un ✕ sube el contador" do
    initiative, report = verified(:unmet, :met)

    Pipeline::SendBack.call(initiative: initiative, to: :neo,
                            verification_report: report)

    assert_equal 1, initiative.reload.qa_cycles_consumed
  end

  test "tres ? no lo suben" do
    initiative, report = verified(:inconclusive, :inconclusive, :inconclusive)

    Pipeline::SendBack.call(initiative: initiative, to: :neo,
                            verification_report: report)

    assert_equal 0, initiative.reload.qa_cycles_consumed
  end

  test "dos ⊗ tampoco" do
    initiative, report = verified(:unsupported, :unsupported)

    Pipeline::SendBack.call(initiative: initiative, to: :neo,
                            verification_report: report)

    assert_equal 0, initiative.reload.qa_cycles_consumed
  end

  test "y el bucle de MORFEO tampoco: revisa ANTES de ejecutar" do
    initiative = place(build_initiative, :morfeo)

    Pipeline::SendBack.call(initiative: initiative, to: :neo, actor: "MORFEO")

    assert_equal 2, initiative.reload.iteration
    assert_equal 0, initiative.qa_cycles_consumed
  end

  test "el rechazo de GATE 2 tampoco: no es un ✕ de SERAPH" do
    initiative = place(build_initiative, :gate_2)

    Pipeline::SendBack.call(initiative: initiative, to: :neo, actor: "Antonio")

    assert_equal 2, initiative.reload.iteration
    assert_equal 0, initiative.qa_cycles_consumed
  end

  # La decisión está concentrada, y por eso un solo test la protege. Lo que se
  # vigila no es cuántos ficheros la CONSULTAN —los que quieran— sino cuántos
  # SUBEN el contador: si hubiera dos, uno se olvidaría de mirar el tope.
  test "el contador lo sube un solo sitio, y lo resetea otro" do
    assert_equal [ "app/services/pipeline/send_back.rb" ],
                 sources_matching(/qa_cycles_consumed\]\s*=/)
    assert_equal [ "app/services/pipeline/restart.rb" ],
                 sources_matching(/qa_cycles_consumed: 0/)
  end

  test "y la decisión de si consume vive en el modelo, no en el servicio" do
    assert_respond_to VerificationReport.new, :consumes_cycle?
    assert_match(/verification_report&?\.?.*consumes_cycle\?/,
                 Rails.root.join("app/services/pipeline/send_back.rb").read)
  end

  private
    def sources_matching(pattern)
      Dir[Rails.root.join("app/**/*.rb"), Rails.root.join("lib/**/*.rb")]
        .select { |file| File.read(file).match?(pattern) }
        .map { |file| Pathname(file).relative_path_from(Rails.root).to_s }
    end

    def verified(*results)
      dod = build_dod
      report = build_report(dod: dod)
      results.each_with_index do |result, index|
        Verdict.create!(verification_report: report, result: result,
                        dod_criterion: build_criterion(dod: dod, key: "c#{index}"))
      end

      [ place(dod.initiative, :seraph_verification), report.reload ]
    end
end
