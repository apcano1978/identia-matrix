# frozen_string_literal: true

require "test_helper"

# La gramática de citas queda congelada en F0. Estos tests son el contrato:
# si alguno se pone rojo, es que alguien cambió una gramática que no se puede
# cambiar, porque los artefactos ya emitidos son inmutables.
class Citations::GrammarTest < ActiveSupport::TestCase
  # El corpus vive en test/support/citation_corpus.rb, compartido con el test
  # del contrato: los dos tienen que aceptar y rechazar exactamente lo mismo.

  test "todas las citas del corpus válido parsean" do
    CitationCorpus::VALID.each do |raw|
      assert Citations::Parse.call(raw), "debería parsear: #{raw}"
    end
  end

  test "las citas literales de la maqueta parsean" do
    # Estas son las que aparecen escritas enteras en la maqueta aprobada. Si
    # alguna dejara de parsear, la gramática habría cambiado de forma que
    # invalida documentos ya diseñados.
    CitationCorpus::MOCKUP.each do |raw|
      assert Citations::Parse.call(raw), "debería parsear: #{raw}"
    end
  end

  test "cada forma inválida del corpus se rechaza, por su motivo" do
    CitationCorpus::INVALID.each do |raw, motivo|
      assert_nil Citations::Parse.call(raw), "debería rechazar #{raw} · #{motivo}"
    end
  end

  test "call! levanta donde call devuelve nil" do
    assert_raises(Citations::Parse::InvalidCitation) do
      Citations::Parse.call!("[src:code/rates.ts#L40]")
    end
  end

  # --- Las dos enmiendas aditivas -------------------------------------------

  test "close es el noveno tipo de fuente, y es DERIVADO" do
    ref = Citations::Parse.call!("[src:close/close-002#§3]")

    assert_equal "close",      ref.kind
    assert_equal "close-002",  ref.locator
    assert_equal "§3",         ref.anchor
    assert ref.derived?
    assert_equal 9, Citations::Grammar::KINDS.size
  end

  test "una reunión admite sufijo, y el locator sigue siendo la fecha" do
    # La trampa: si el grupo se llamara `slug`, locator_for devolvería el sufijo
    # en lugar de la fecha y la resolución apuntaría a otro sitio, en silencio.
    corta = Citations::Parse.call!("[src:meet/2026-05-02@22:40]")
    larga = Citations::Parse.call!("[src:meet/2026-05-02-unificacion-precio@22:40]")

    assert_equal "2026-05-02", corta.locator
    assert_nil   corta.meeting_slug

    assert_equal "2026-05-02",          larga.locator
    assert_equal "unificacion-precio",  larga.meeting_slug
    assert_equal "22:40",               larga.clock
  end

  test "guide no es un tipo de fuente" do
    # Un paso de guía es un destino al que se apunta, no un origen que se cite.
    # La redirección ya está modelada como relación, no como cita.
    assert_nil Citations::Parse.call("[src:guide/guia-pruebas-031#p03]")
    refute_includes Citations::Grammar::KINDS, "guide"
  end

  # --- Lo que se extrae de cada forma ---------------------------------------

  test "una cita de código descompone repositorio, ruta, línea y commit" do
    ref = Citations::Parse.call!("[src:code/booking-core:rates.ts#L40@4f2a9c1]")

    assert_equal "code",         ref.kind
    assert_equal "booking-core", ref.repository
    assert_equal "rates.ts",     ref.locator
    assert_equal "L40",          ref.anchor
    assert_equal "4f2a9c1",      ref.commit_sha
    assert ref.pinned?
  end

  test "una cita de código admite rutas con subdirectorios" do
    ref = Citations::Parse.call!("[src:code/pricing-svc:src/rules/holiday.ts@b7c0d21]")

    assert_equal "pricing-svc",          ref.repository
    assert_equal "src/rules/holiday.ts", ref.locator
    assert_nil   ref.anchor
    assert_equal "b7c0d21",              ref.commit_sha
  end

  test "una cita de reunión descompone fecha y minuto" do
    ref = Citations::Parse.call!("[src:meet/2026-05-02@22:40]")

    assert_equal "meet",       ref.kind
    assert_equal "2026-05-02", ref.locator
    assert_equal "22:40",      ref.clock
    assert_nil   ref.repository
  end

  test "una nota humana descompone fecha y autor" do
    ref = Citations::Parse.call!("[src:note/2026-05-08-ap]")

    assert_equal "note",       ref.kind
    assert_equal "2026-05-08", ref.locator
    assert_equal "ap",         ref.author
  end

  test "una cita de documento descompone slug y párrafo" do
    ref = Citations::Parse.call!("[src:doc/acta-precios#p2]")

    assert_equal "doc",           ref.kind
    assert_equal "acta-precios",  ref.locator
    assert_equal "p2",            ref.anchor
  end

  test "una cita de spec descompone la seccion" do
    ref = Citations::Parse.call!("[src:spec/spec-031#§7]")

    assert_equal "spec-031", ref.locator
    assert_equal "§7",       ref.anchor
  end

  # --- Niveles de procedencia -----------------------------------------------

  test "codigo, documentos, reuniones y notas son ORIGEN" do
    %w[code doc meet note].each do |kind|
      assert_equal :origin, Citations::Grammar.level(kind), "#{kind} debería ser origen"
    end
  end

  test "spec, dod, verify y pkg son DERIVADO" do
    %w[spec dod verify pkg].each do |kind|
      assert_equal :derived, Citations::Grammar.level(kind), "#{kind} debería ser derivado"
    end
  end

  test "el nivel se deriva del tipo, no se almacena" do
    origin  = Citations::Parse.call!("[src:doc/acta-precios#p2]")
    derived = Citations::Parse.call!("[src:dod/dod-031#c3]")

    assert origin.origin?
    assert_equal "◆", origin.glyph

    assert derived.derived?
    assert_equal "↳", derived.glyph
  end

  test "un tipo desconocido no tiene nivel" do
    assert_raises(ArgumentError) { Citations::Grammar.level("slack") }
  end

  # --- Escaneo de un cuerpo markdown ----------------------------------------

  test "scan extrae las citas de un cuerpo en orden y separa las rotas" do
    body = <<~MD
      ## Precio efectivo en el calendario

      El calendario deja de calcular tarifa y la pide a pricing-svc,
      que pasa a ser la única autoridad de precio. [src:doc/acta-precios#p2]

      La tarifa vivía duplicada en dos repositorios:
      [src:code/booking-core:rates.ts#L40@4f2a9c1]
      [src:code/owner-web:priceLabel.tsx#L22@e91b330]

      Y esta está mal escrita: [src:code/rates.ts#L40]

      El contrato v1 se mantiene hasta cerrar la ventana. [src:dod/dod-031#c0]
    MD

    valid, invalid = Citations::Parse.scan(body)

    assert_equal %w[doc code code dod], valid.map(&:kind)
    assert_equal [ "[src:code/rates.ts#L40]" ], invalid
  end

  test "scan sobre un cuerpo sin citas no devuelve nada" do
    valid, invalid = Citations::Parse.scan("Un párrafo sin una sola cita.")

    assert_empty valid
    assert_empty invalid
  end
end
