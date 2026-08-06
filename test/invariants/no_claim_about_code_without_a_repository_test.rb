require "test_helper"

# INVARIANTE 4 · Ninguna afirmación sobre el código sin fichero, repositorio y
# commit.
#
# Es lo que separa una cita comprobable de una referencia decorativa. Sin
# repositorio, `rates.ts#L40` no dice de cuál de los tres repositorios habla.
class NoClaimAboutCodeWithoutARepositoryTest < ActiveSupport::TestCase
  test "una cita de código sin repositorio no llega a la base de datos" do
    citation = Citation.new(citable: build_artifact, source_kind: :code,
                            raw: "[src:code/booking-core:rates.ts#L40@4f2a9c1]",
                            locator: "rates.ts")

    assert_not citation.valid?
    assert_includes citation.errors.attribute_names, :repository
  end

  test "la gramática tampoco acepta el texto sin calificador" do
    assert_nil Citations::Parse.call("[src:code/rates.ts#L40@4f2a9c1]")
  end

  test "una cita de evidencia de verificación tampoco" do
    citation = Citation.new(citable: build_artifact, source_kind: :verify,
                            raw: "[src:verify/pricing-svc:run-174#L88]",
                            locator: "run-174")

    assert_not citation.valid?
  end

  test "los dos tipos que exigen repositorio son exactamente code y verify" do
    assert_equal %w[code verify], Citations::Grammar::REPOSITORY_QUALIFIED_KINDS
  end

  test "en el seed, todas las citas de código resuelven contra su repositorio" do
    DesignSeed.call

    Citation.kind_code.find_each do |citation|
      assert_not_nil citation.repository, "#{citation.raw} sin repositorio"
      assert_not_nil citation.commit_sha, "#{citation.raw} sin commit"
    end
  end
end
