# frozen_string_literal: true

require "test_helper"

class CitationsHelperTest < ActionView::TestCase
  include CitationsHelper
  include UiHelper

  setup do
    @client = build_client(slug: "vivla")
    @initiative = build_initiative(client: @client, code: "ev-031")
    @artifact = build_artifact(initiative: @initiative, kind: :spec)
  end

  # ── Los tres tonos ─────────────────────────────────────────────────────────

  test "el código es verde, y el resto del origen es oro" do
    assert_equal :origin_code,
                 tone("[src:code/booking-core:rates.ts#L40@4f2a9c1]")

    assert_equal :origin_doc, tone("[src:doc/acta-precios#p2]")
    assert_equal :origin_doc, tone("[src:meet/2026-05-02@22:40]")
    assert_equal :origin_doc, tone("[src:note/2026-05-08-ap]")
  end

  test "los cinco tipos derivados van con el tono derivado" do
    %w[spec dod pkg close].each do |kind|
      assert_equal :derived, tone("[src:#{kind}/#{kind}-031#§1]")
    end

    assert_equal :derived, tone("[src:verify/pricing-svc:run-174#L88]"),
                 "verify es derivada aunque lleve calificador de repositorio"
  end

  test "el chip derivado lleva el borde discontinuo y los de origen no" do
    assert_includes chip("[src:spec/spec-031#§2]"), "border-dashed"

    refute_includes chip("[src:doc/acta-precios#p2]"), "border-dashed"
    refute_includes chip("[src:code/booking-core:rates.ts#L40@4f2a9c1]"),
                    "border-dashed"
  end

  test "el chip lleva el glifo del nivel" do
    assert_includes chip("[src:doc/acta-precios#p2]"), "◆"
    assert_includes chip("[src:spec/spec-031#§2]"), "↳"
  end

  # ── §7.4 · el formateador único ───────────────────────────────────────────

  # Las dos filas donde la maqueta se salta su propia gramática. No se copian:
  # la columna TRAZA renderiza exactamente la misma cita que guarda la tabla,
  # solo que sin el envoltorio.
  test "la forma compacta respeta la gramática donde la maqueta no lo hace" do
    assert_equal "↳ pkg/pkg-045#deploy", compact("[src:pkg/pkg-045#deploy]")
    refute_equal "↳ trinity/pkg-045#deploy", compact("[src:pkg/pkg-045#deploy]")

    assert_equal "↳ spec/spec-031#§7", compact("[src:spec/spec-031#§7]")
    refute_equal "↳ spec-031#§7", compact("[src:spec/spec-031#§7]")
  end

  # La aserción que impide que la divergencia vuelva: la forma compacta NO se
  # recompone a partir de las columnas, se deriva de lo que se escribió. Si
  # alguien la recompone, esto falla para todo el corpus a la vez.
  test "la forma compacta es siempre el texto de la cita, sin sus extremos" do
    CitationCorpus::VALID.each do |raw|
      citation = Citation.from_raw(raw, citable: @artifact)

      assert_equal raw[5..-2], citation.compact,
                   "#{raw} se está recomponiendo en vez de derivarse"
    end
  end

  # ── El extracto ───────────────────────────────────────────────────────────

  test "resalta la frase declarada dentro del párrafo citado" do
    citation = with_document(
      body: "Se acuerda una única autoridad de precio, consultada por el resto.",
      quote: "una única autoridad de precio")

    excerpt = citation_excerpt(citation)

    assert_includes excerpt, "<mark"
    assert_includes excerpt, "una única autoridad de precio"
    assert_includes excerpt, "consultada por el resto"
  end

  # Adivinar la frase resaltaría lo que no era: sin declararla, el párrafo va
  # entero y sin marca.
  test "sin frase declarada, el párrafo va sin marca" do
    citation = with_document(body: "Se acuerda una sola fuente.", quote: nil)

    refute_includes citation_excerpt(citation), "<mark"
  end

  test "una frase que no está en el cuerpo no se inventa" do
    citation = with_document(body: "Se acuerda una sola fuente.",
                             quote: "lo que nadie dijo")

    refute_includes citation_excerpt(citation), "<mark"
  end

  # El PDF del que nadie extrajo texto es un caso real: se lista y se puede
  # citar, pero el bloque se omite en vez de enseñar un hueco.
  test "una fuente sin cuerpo no produce extracto" do
    assert_nil citation_excerpt(with_document(body: nil, quote: "lo que sea"))
  end

  test "una cita sin fuente resuelta tampoco" do
    assert_nil citation_excerpt(build_citation("[src:doc/no-existe#p1]"))
  end

  private
    def build_citation(raw, **attributes)
      Citation.from_raw(raw, citable: @artifact, **attributes)
    end

    def tone(raw) = citation_tone(build_citation(raw))
    def compact(raw) = citation_compact(build_citation(raw))

    def chip(raw)
      citation_chip(build_citation(raw)).to_s
    end

    def with_document(body:, quote:)
      document = build_document(client: @client, slug: "acta-precios",
                                body: body)

      build_citation("[src:doc/acta-precios#p2]", quote: quote,
                                                  target: document)
    end
end
