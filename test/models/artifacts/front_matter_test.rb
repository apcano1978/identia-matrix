# frozen_string_literal: true

require "test_helper"

class Artifacts::FrontMatterTest < ActiveSupport::TestCase
  BODY = <<~MD.freeze
    ## El contrato contra el que se verifica

    SERAPH lo redacta a partir de spec-031. [src:spec/spec-031#§2]
  MD

  def attributes(**overrides)
    Artifacts::FrontMatter.build(
      key: "artifacts://vivla/ev-031/dod-031/v2.md",
      kind: :dod,
      code: "dod-031",
      version: 2,
      initiative: "ev-031",
      client: "vivla",
      produced_by: "seraph/run-166",
      produced_at: Time.zone.parse("2026-05-28 10:04:18"),
      derives_from: "artifacts://vivla/ev-031/spec-031/v4.md",
      checksum: Artifacts::FrontMatter.checksum_for(BODY)
    ).merge(overrides)
  end

  test "render antepone los diez campos al cuerpo" do
    document = Artifacts::FrontMatter.render(attributes, BODY)

    assert document.start_with?("---\n")
    Artifacts::FrontMatter::FIELDS.each do |field|
      assert_includes document, "#{field}: "
    end
    assert_includes document, "## El contrato contra el que se verifica"
  end

  test "render y parse son simetricos" do
    document = Artifacts::FrontMatter.render(attributes, BODY)
    parsed, body = Artifacts::FrontMatter.parse(document)

    assert_equal "artifacts://vivla/ev-031/dod-031/v2.md", parsed[:key]
    assert_equal "dod",                                    parsed[:kind]
    assert_equal "dod-031",                                parsed[:code]
    assert_equal 2,                                        parsed[:version]
    assert_equal "ev-031",                                 parsed[:initiative]
    assert_equal "vivla",                                  parsed[:client]
    assert_equal "seraph/run-166",                         parsed[:produced_by]
    assert_equal "artifacts://vivla/ev-031/spec-031/v4.md", parsed[:derives_from]
    assert_equal BODY.strip,                               body.strip
  end

  test "la version se recupera como entero" do
    document = Artifacts::FrontMatter.render(attributes, BODY)
    parsed, _ = Artifacts::FrontMatter.parse(document)

    assert_kind_of Integer, parsed[:version]
  end

  test "derives_from puede faltar: el dossier de TANK arranca la cadena" do
    attrs = attributes(derives_from: nil, kind: "dossier", code: "dossier-038")
    document = Artifacts::FrontMatter.render(attrs, BODY)
    parsed, _ = Artifacts::FrontMatter.parse(document)

    assert_nil parsed[:derives_from]
  end

  test "cualquier otro campo obligatorio que falte revienta" do
    (Artifacts::FrontMatter::REQUIRED).each do |field|
      assert_raises(ArgumentError, "debería exigir #{field}") do
        Artifacts::FrontMatter.render(attributes(field => nil), BODY)
      end
    end
  end

  test "parse sobre un documento sin front-matter devuelve el cuerpo intacto" do
    parsed, body = Artifacts::FrontMatter.parse(BODY)

    assert_empty parsed
    assert_equal BODY, body
  end

  # `parse` reconoce cualquier bloque `---…---` inicial y se queda solo con los
  # diez campos que conoce: sobre una cabecera ajena devuelve `{}` y **se lleva
  # el bloque por delante**. No es un fallo —el formato no permite distinguirlo—
  # pero sí la razón por la que `Artifact#body_markdown` no puede llamar a esto
  # a ciegas: comprueba que la cabecera dice ser la suya antes de descartarla.
  test "parse no reclama como suya la cabecera de una fixture de agente" do
    fixture = <<~MARKDOWN
      ---
      citations:
        - "[src:doc/acta-precios#p2]"
      findings: []
      ---

      # El cuerpo
    MARKDOWN

    attributes, = Artifacts::FrontMatter.parse(fixture)

    assert_empty attributes, "ninguno de sus campos es de artefacto"
  end

  # En la dirección contraria el sistema tiene suerte, y conviene dejarlo
  # escrito: `Runtime::Fixture.split` usa `YAML.safe_load`, que se niega a
  # construir el `Time` de `produced_at`. Pasarle un documento de artefacto
  # **revienta**, en vez de comerse la cabecera en silencio y devolver un cuerpo
  # mutilado. Si algún día `produced_at` dejara de ser una fecha, este test cae
  # y avisa de que la protección era accidental.
  test "y pasarle un documento de artefacto a Runtime::Fixture falla ruidosamente" do
    document = Artifacts::FrontMatter.render(attributes, BODY)

    assert_raises(Psych::DisallowedClass) { Runtime::Fixture.split(document) }
  end

  test "el checksum cambia si cambia un solo caracter del cuerpo" do
    original = Artifacts::FrontMatter.checksum_for(BODY)
    altered  = Artifacts::FrontMatter.checksum_for(BODY.sub("SERAPH", "MORFEO"))

    assert_match(/\Asha256:[0-9a-f]{64}\z/, original)
    refute_equal original, altered
  end
end
