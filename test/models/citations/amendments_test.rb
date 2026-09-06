# frozen_string_literal: true

require "test_helper"

# EL CANDADO DE LA GRAMÁTICA.
#
# Los artefactos son inmutables: una cita ya emitida vive dentro de un markdown
# que nadie puede reescribir. Por eso la gramática se declaró CERRADA el 4 de
# septiembre de 2026, cuando TANK produjo el primer artefacto real.
#
# F11 la reabre una sola vez, para añadir `acta` y el ancla `#abierta-N`, y con
# un argumento que NO vale para cualquier enmienda: añadir un tipo que antes no
# existía no puede cambiar cómo se interpreta ninguna cita ya emitida, porque no
# hay texto anterior que empiece por `[src:acta/`.
#
# Este test es lo que convierte ese argumento en algo comprobado. No comprueba
# «siguen siendo válidas» —eso lo pasaría una enmienda que las hiciera resolver
# a otro sitio— sino que cada una sigue significando EXACTAMENTE lo mismo, campo
# a campo, contra el fósil de CitationCorpus::INTERPRETATIONS.
#
# Cualquier enmienda futura tiene que pasar por aquí.
class Citations::AmendmentsTest < ActiveSupport::TestCase
  # El corpus contra el que se compara: el versionado a mano más las citas
  # LITERALES de los fixtures, que es lo que un agente produce. Se compone
  # escaneando en vez de fijarse a mano para que añadir una cita a un fixture no
  # pueda quedarse fuera del candado sin que nadie se entere.
  def corpus
    fixtures = Dir[Rails.root.join("lib/runtime/fixtures/**/*.md")]
                 .flat_map { |path| File.read(path).scan(Citations::Grammar::SCANNER) }

    (CitationCorpus::VALID + fixtures).uniq
  end

  test "ninguna cita del fosil cambia de interpretacion" do
    cambiadas = CitationCorpus::INTERPRETATIONS.filter_map do |raw, esperada|
      real = Citations::Parse.call(raw)&.to_h&.except(:raw)&.compact

      next if real == esperada

      "#{raw}\n    fósil: #{esperada.inspect}\n    ahora: #{real.inspect}"
    end

    assert_empty cambiadas, <<~MSG
      Una enmienda cambió el significado de una cita YA EMITIDA.

      Esto no se arregla regenerando el fósil: se arregla deshaciendo la
      enmienda. Lo que hay al otro lado de estas citas son artefactos inmutables
      que nadie puede reescribir.

      #{cambiadas.join("\n\n  ")}
    MSG
  end

  test "el fosil cubre el corpus entero y no se ha vaciado" do
    # Sin este mínimo, un refactor que dejara el escaneo sin encontrar nada
    # dejaría el candado en verde para siempre. Es el mismo fallo que SourceScan
    # documenta: un test que afirma sobre un conjunto vacío pasa.
    assert_operator CitationCorpus::INTERPRETATIONS.size, :>=, 34

    sin_fosilizar = corpus - CitationCorpus::INTERPRETATIONS.keys

    assert_empty sin_fosilizar, <<~MSG
      Hay citas en el corpus que el fósil no cubre, así que nadie vigila su
      interpretación. Añádelas a CitationCorpus::INTERPRETATIONS con lo que el
      parser devuelve HOY, después de comprobar que es lo que debe devolver.

      #{sin_fosilizar.join("\n  ")}
    MSG
  end

  test "las citas mal formadas se siguen rechazando todas" do
    aceptadas = CitationCorpus::INVALID.keys.select { |raw| Citations::Parse.call(raw) }

    assert_empty aceptadas, <<~MSG
      Una enmienda hizo válida una cita que estaba rechazada a propósito.
      Cada entrada de INVALID lleva escrito el error que representa; promover
      una a válida es una decisión, no un efecto colateral.

      #{aceptadas.join("\n  ")}
    MSG
  end

  test "el acta se cita, y es de nivel origen" do
    referencia = Citations::Parse.call("[src:acta/arquitecto-031#abierta-1]")

    assert_equal "acta",            referencia.kind
    assert_equal "arquitecto-031",  referencia.locator
    assert_equal "abierta-1",       referencia.anchor
    assert_equal :origin, Citations::Grammar.level("acta")

    # Y resuelve contra un artefacto aunque sea de origen: es la asimetría que
    # obliga a que ARTIFACT_KINDS sea una lista explícita y no una resta.
    assert_includes Citations::Grammar::ARTIFACT_KINDS, "acta"
    refute_includes Citations::Grammar::DERIVED_KINDS,  "acta"
  end

  test "el ancla de decision no se cuela en los demas tipos" do
    %w[doc spec dod pkg close].each do |kind|
      assert_nil Citations::Parse.call("[src:#{kind}/lo-que-sea#abierta-1]"),
                 "#{kind} no admite un ancla de decisión"
    end
  end

  # ── EL CANDADO DEL CANDADO ──────────────────────────────────────────────────
  #
  # Los dos tests que siguen no comprueban la gramática: comprueban que este
  # fichero SABE PONERSE ROJO. Sin ellos, un refactor que vaciara el corpus o
  # relajara una aserción dejaría todo en verde sin proteger nada, y eso no lo
  # detecta nadie porque un test que pasa no se mira.
  #
  # Cada uno aplica sobre una copia la enmienda peligrosa que de verdad se
  # consideró, y afirma que la aserción correspondiente la habría cazado.

  test "una enmienda que sacara el ordinal de la nota fuera del autor se cazaria" do
    # La forma que se descartó en P8: sufijo SUELTO en vez de anidado tras el
    # autor. Con ella, `note/2026-08-17-antonio` parsea SIN autor, y
    # Citations::Resolve#note cae a un LIKE que devuelve la primera nota del día
    # — resolvería a la nota equivocada, en silencio, dentro de un artefacto
    # inmutable.
    suelto = "(?:-(?<author>[a-z]{2,4}))?(?:-(?<note_slug>[a-z0-9]+(?:-[a-z0-9]+)*))?"
    peligrosa = Regexp.new(
      "\\A\\[src:(?<kind>note)/#{Citations::Grammar::DATE}#{suelto}#{Citations::Grammar::ANCHOR}\\]\\z")

    casada = peligrosa.match("[src:note/2026-08-17-antonio]")

    assert casada, "la enmienda peligrosa tiene que hacer parsear esto: por eso es peligrosa"
    assert_nil casada[:author], "y parsearía SIN autor, que es el daño concreto"

    # Y esto es lo que la caza: hoy esa cita está en INVALID y no parsea.
    assert_includes CitationCorpus::INVALID.keys, "[src:note/2026-08-17-antonio]"
    assert_nil Citations::Parse.call("[src:note/2026-08-17-antonio]")
  end

  test "meter el ancla de decision en ANCHOR habria ensanchado siete tipos mas" do
    # El atajo que se descartó en F11: en vez de un cuerpo nuevo para `acta`,
    # añadir `abierta-\d+` al ANCHOR general. Es una línea menos y acepta de
    # rebote formas que nadie pidió.
    ancho = '(?:#(?<anchor>L\d+|p\d+|§\d+|c\d+|deploy|(?:abierta|cerrada|descartada)-\d+))?'
    peligrosa = Regexp.new(
      "\\A\\[src:(?<kind>doc|spec|dod|pkg|close)/#{Citations::Grammar::SLUG}#{ancho}\\]\\z")

    assert peligrosa.match("[src:doc/acta-precios#abierta-1]"),
           "con el ancla en ANCHOR, un documento admitiría un ancla de decisión"

    # Con el cuerpo aparte, no.
    assert_nil Citations::Parse.call("[src:doc/acta-precios#abierta-1]")
  end
end
