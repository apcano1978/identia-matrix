# frozen_string_literal: true

require "test_helper"

# La única forma de crear una cita. Lo que se prueba aquí es sobre todo que no
# se pierde nada al pasar dos veces: hasta F4 la lógica vivía triplicada y la
# copia del paseo no resolvía la fuente en absoluto.
class Citations::AttachTest < ActiveSupport::TestCase
  setup do
    @client = build_client(slug: "vivla")
    @initiative = build_initiative(client: @client, code: "ev-031")
    @artifact = build_artifact(initiative: @initiative, kind: :spec)
    @repository = build_repository(client: @client, name: "booking-core")
    @document = build_document(client: @client, slug: "acta-precios")
  end

  test "saca las citas del cuerpo, en el orden en que aparecen" do
    citations = attach(<<~BODY)
      Unificar el precio [src:doc/acta-precios#p2].
      `rates.ts` lo expone [src:code/booking-core:rates.ts#L40@4f2a9c1].
    BODY

    assert_equal [ "[src:doc/acta-precios#p2]",
                   "[src:code/booking-core:rates.ts#L40@4f2a9c1]" ],
                 citations.map(&:raw)
    assert_equal [ 0, 1 ], citations.map(&:position)
  end

  test "resuelve la fuente y el calificador de repositorio" do
    doc, code = attach(<<~BODY)
      [src:doc/acta-precios#p2] y [src:code/booking-core:rates.ts#L40@4f2a9c1]
    BODY

    assert_equal @document, doc.target
    assert_nil doc.repository, "un documento no lleva calificador de repositorio"

    assert_equal @repository, code.target
    assert_equal @repository, code.repository
    assert_equal "4f2a9c1", code.commit_sha
  end

  test "la misma cita dos veces en un cuerpo es una sola fila" do
    citations = attach(<<~BODY)
      [src:doc/acta-precios#p2] al principio y [src:doc/acta-precios#p2] al final.
    BODY

    assert_equal 1, citations.size
    assert_equal 1, @artifact.citations.count
  end

  test "es idempotente: dos pasadas dejan las mismas filas" do
    body = "[src:doc/acta-precios#p2] y [src:code/booking-core:rates.ts#L40@4f2a9c1]"

    primera = attach(body).map(&:id).sort
    assert_equal primera, attach(body).map(&:id).sort
    assert_equal 2, @artifact.citations.count
  end

  # Lo que distingue a Attach de un `next if exists?`: una cita que se guardó
  # cuando su fuente todavía no existía queda resuelta en la siguiente pasada.
  # Sin esto, una base de desarrollo se queda con `target` nulo para siempre y
  # ningún test se entera, porque los tests arrancan limpios.
  test "cura una cita que se guardó antes de que su fuente existiera" do
    citation = attach("[src:spec/spec-999#§2]").sole
    assert_nil citation.target, "todavía no hay contra qué resolver"

    otro = build_initiative(client: @client, code: "ev-999")
    artifact = build_artifact(initiative: otro, kind: :spec)
    assert_equal "spec-999", artifact.code

    assert_equal artifact, attach("[src:spec/spec-999#§2]").sole.target
    assert_equal citation.id, @artifact.citations.sole.id,
                 "cura la fila que ya había, no crea otra"
  end

  test "un texto que la gramática rechaza no llega a guardarse" do
    assert_empty attach("[src:code/rates.ts#L40] sin calificador de repositorio")
    assert_equal 0, @artifact.citations.count
  end

  # INVARIANTE 4, por su lado más incómodo: la cita es gramaticalmente válida,
  # pero el repositorio que nombra no es de este cliente. No resuelve, y sin
  # repositorio la fila no pasa la validación.
  test "una cita de código a un repositorio de otro cliente no se guarda" do
    build_repository(client: build_client(slug: "caser"), name: "owner-web")

    assert_raises(ActiveRecord::RecordInvalid) do
      attach("[src:code/owner-web:priceLabel.tsx#L22@e91b330]")
    end
  end

  # ── Attach.one, para las citas que no salen de un cuerpo ───────────────────

  test "one ata una cita suelta con su fuente resuelta" do
    citation = Citations::Attach.one(citable: @artifact,
                                     raw: "[src:doc/acta-precios#p2]",
                                     client: @client.id)

    assert_equal @document, citation.target
    assert_equal 0, citation.position
  end

  test "one guarda la frase citada cuando quien emite la cita la declara" do
    citation = Citations::Attach.one(
      citable: @artifact, raw: "[src:doc/acta-precios#p2]", client: @client.id,
      quote: "una única autoridad de precio")

    assert_equal "una única autoridad de precio", citation.quote
  end

  test "one devuelve nulo ante un texto que no es una cita" do
    assert_nil Citations::Attach.one(citable: @artifact, raw: "no es una cita",
                                     client: @client.id)
    assert_nil Citations::Attach.one(citable: @artifact, raw: nil,
                                     client: @client.id)
  end

  private
    def attach(body)
      Citations::Attach.body(citable: @artifact, body: body,
                             client: @client.id)
    end
end
