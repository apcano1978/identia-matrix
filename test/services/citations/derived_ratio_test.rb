# frozen_string_literal: true

require "test_helper"

class Citations::DerivedRatioTest < ActiveSupport::TestCase
  setup do
    @client = build_client(slug: "vivla")
    @initiative = build_initiative(client: @client, code: "ev-031")
    @artifact = build_artifact(initiative: @initiative, kind: :spec)
  end

  # El caso literal de la maqueta: el aviso salta con 3 de 12 —el 25 % justo—
  # y por eso el umbral es INCLUSIVE. Con `>` este caso no saltaría.
  test "salta con 3 de 12 y no salta con 2 de 12" do
    assert ratio_of(derived: 3, origin: 9).over?,
           "3 de 12 es el 25 % justo: el umbral es inclusive"

    refute ratio_of(derived: 2, origin: 10).over?
  end

  test "cuenta los dos niveles y el total" do
    ratio = ratio_of(derived: 3, origin: 9)

    assert_equal 3, ratio.derived
    assert_equal 9, ratio.origin
    assert_equal 12, ratio.total
    assert_in_delta 0.25, ratio.ratio
  end

  test "el aviso nombra las dos cifras" do
    assert_equal "3 de 12 citas son derivadas. " \
                 "El corpus empieza a alimentarse de sí mismo.",
                 ratio_of(derived: 3, origin: 9).notice
  end

  test "un artefacto sin citas no salta ni divide por cero" do
    ratio = Citations::DerivedRatio.for(@artifact)

    assert_equal 0, ratio.total
    assert_equal 0.0, ratio.ratio
    refute ratio.over?
  end

  test "un artefacto nulo devuelve un ratio vacío" do
    refute Citations::DerivedRatio.for(nil).over?
  end

  # ── El umbral es política de MORFEO, y hereda como el resto ────────────────

  test "sin configuración sembrada cae al 25 % por defecto" do
    assert_equal Citations::DerivedRatio::DEFAULT_THRESHOLD,
                 Citations::DerivedRatio.threshold_for(@client.id)
  end

  test "la configuración global de MORFEO manda sobre el respaldo" do
    AgentConfig.create!(agent: :morfeo,
                        settings: { "revision" => { "derived_ratio_threshold" => 0.5 } })

    assert_in_delta 0.5, Citations::DerivedRatio.threshold_for(@client.id)
    refute ratio_of(derived: 3, origin: 9).over?, "3 de 12 ya no llega al 50 %"
  end

  test "un cliente puede endurecer el umbral con su override" do
    AgentConfig.create!(agent: :morfeo,
                        settings: { "revision" => { "derived_ratio_threshold" => 0.5 } })
    AgentConfig.create!(agent: :morfeo, platform_client: @client,
                        settings: { "revision" => { "derived_ratio_threshold" => 0.1 } })

    assert_in_delta 0.1, Citations::DerivedRatio.threshold_for(@client.id)
    assert ratio_of(derived: 3, origin: 9).over?
  end

  private
    # Cuelga del artefacto tantas citas de cada nivel como se pidan. Las de
    # origen son documentos y las derivadas specs: lo que importa es el nivel,
    # que la gramática deriva de `source_kind`.
    def ratio_of(derived:, origin:)
      origin.times do |index|
        build_citation("[src:doc/acta-#{index}#p1]")
      end
      derived.times do |index|
        build_citation("[src:spec/spec-#{format('%03d', index)}#§1]")
      end

      Citations::DerivedRatio.for(@artifact.reload)
    end

    def build_citation(raw)
      Citation.from_raw(raw, citable: @artifact).save!
    end
end
