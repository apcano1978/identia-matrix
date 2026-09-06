# frozen_string_literal: true

require "test_helper"

# Las claves de artefacto quedan congeladas en F0. Un artefacto publicado no se
# reescribe, así que un cambio aquí rompe todo lo ya emitido.
class Artifacts::KeyTest < ActiveSupport::TestCase
  test "construye la clave que enseña la maqueta" do
    assert_equal "artifacts://vivla/ev-031/dod-031/v2.md",
                 Artifacts::Key.for(client: "vivla", initiative: "ev-031", kind: :dod, number: 31, version: 2)

    assert_equal "artifacts://vivla/ev-031/close-031/v1.md",
                 Artifacts::Key.for(client: "vivla", initiative: "ev-031", kind: :close, number: 31, version: 1)
  end

  test "el repositorio no aparece en la ruta" do
    # ev-031 toca booking-core, owner-web y pricing-svc. El artefacto es del
    # evolutivo, no de un repositorio: no habría cuál elegir.
    key = Artifacts::Key.for(client: "vivla", initiative: "ev-031", kind: :spec, number: 31, version: 4)

    # Exactamente cliente / evolutivo / código / fichero. Ni un segmento más.
    assert_equal %w[vivla ev-031 spec-031 v4.md], key.delete_prefix("artifacts://").split("/")
    refute_includes key, "booking-core"
  end

  test "spec, dod, guide, verify y close heredan el numero del evolutivo" do
    number = Artifacts::Key.number_from_initiative("ev-031")
    assert_equal 31, number

    assert_equal "spec-031",         Artifacts::Key.code(kind: :spec,  number: number)
    assert_equal "dod-031",          Artifacts::Key.code(kind: :dod,   number: number)
    assert_equal "close-031",        Artifacts::Key.code(kind: :close, number: number)
    assert_equal "guia-pruebas-031", Artifacts::Key.code(kind: :guide, number: number)
  end

  test "pkg tiene secuencia propia, distinta de la del evolutivo" do
    # En la maqueta, ev-031 produce spec-031 pero PKG-045.
    assert_equal "pkg-045", Artifacts::Key.code(kind: :pkg, number: 45)

    assert_equal "artifacts://vivla/ev-031/pkg-045/v1.md",
                 Artifacts::Key.for(client: "vivla", initiative: "ev-031", kind: :pkg, number: 45, version: 1)
  end

  test "el informe de verificacion lleva sufijo de ronda" do
    # verify-031-r2 es el informe del segundo ciclo de QA. Sin el sufijo,
    # pisaría al del primero y se perdería el historial.
    assert_equal "verify-031-r2", Artifacts::Key.code(kind: :verify, number: 31, round: 2)

    assert_equal "artifacts://vivla/ev-031/verify-031-r2/v1.md",
                 Artifacts::Key.for(client: "vivla", initiative: "ev-031", kind: :verify, number: 31, round: 2, version: 1)
  end

  test "solo el informe de verificacion admite ronda" do
    assert_raises(ArgumentError) { Artifacts::Key.code(kind: :dod, number: 31, round: 2) }
  end

  test "un tipo de artefacto desconocido se rechaza" do
    assert_raises(ArgumentError) { Artifacts::Key.code(kind: :informe, number: 31) }
  end

  test "la version empieza en 1" do
    assert_raises(ArgumentError) do
      Artifacts::Key.for(client: "vivla", initiative: "ev-031", kind: :dod, number: 31, version: 0)
    end
  end

  test "el numero se rellena a tres digitos" do
    assert_equal "spec-002", Artifacts::Key.code(kind: :spec, number: 2)
    assert_equal "spec-031", Artifacts::Key.code(kind: :spec, number: 31)
    # Y no se trunca cuando el proyecto pase de los mil evolutivos.
    assert_equal "spec-1024", Artifacts::Key.code(kind: :spec, number: 1024)
  end

  test "parse descompone una clave valida" do
    parsed = Artifacts::Key.parse!("artifacts://vivla/ev-031/verify-031-r2/v3.md")

    assert_equal "vivla",         parsed.client
    assert_equal "ev-031",        parsed.initiative
    assert_equal "verify-031-r2", parsed.code
    assert_equal 3,               parsed.version
  end

  test "rechaza claves mal formadas" do
    [
      "artifacts://vivla/ev-031/dod-031/v2",          # sin extensión
      "artifacts://vivla/ev-031/dod-031.md",          # sin versión
      "s3://vivla/ev-031/dod-031/v2.md",              # otro esquema
      "artifacts://vivla/ev-031/booking-core/dod-031/v2.md", # repositorio en la ruta
      "artifacts://vivla/Ev-031/dod-031/v2.md",       # mayúsculas: un slug es kebab
      "artifacts://vivla/ev_031/dod-031/v2.md"        # guion bajo: tampoco
    ].each do |key|
      refute Artifacts::Key.valid?(key), "debería rechazar: #{key}"
    end
  end

  # F11 · el segundo segmento pasa de `ev-\d{3,}` a SLUG, para que un artefacto
  # se llame `artifacts://matrix-interna/rediseno-interfaz/...` y no por número.
  test "una clave con nombre parsea, y las emitidas con codigo siguen parseando" do
    assert Artifacts::Key.valid?("artifacts://matrix-interna/rediseno-interfaz/spec-042/v1.md")
    assert Artifacts::Key.valid?("artifacts://vivla/ev-031/dod-031/v2.md")

    parsed = Artifacts::Key.parse!("artifacts://matrix-interna/rediseno-interfaz/spec-042/v1.md")
    assert_equal "matrix-interna",   parsed.client
    assert_equal "rediseno-interfaz", parsed.initiative
  end

  # ES LO QUE SE PAGA POR EL ENSANCHAMIENTO, y conviene que esté escrito.
  #
  # Hasta F11 la clave rechazaba `artifacts://vivla/proj-2291/...` porque el
  # segundo segmento tenía forma de evolutivo y `proj-2291` no la tiene. Con un
  # SLUG libre eso deja de poder distinguirse en la forma: la clave ya no sabe
  # sola si el segmento nombra un evolutivo o cualquier otra cosa.
  #
  # No es un descuido y no se compensa estrechando el patrón —eso rompería
  # `rediseno-interfaz`—: se compensa donde se puede comprobar de verdad, que es
  # resolviendo contra la tabla. La clave dice la FORMA; quién existe lo dice el
  # evolutivo.
  test "la forma ya no distingue un evolutivo de cualquier otro slug" do
    assert Artifacts::Key.valid?("artifacts://vivla/proj-2291/dod-031/v2.md")
  end

  # Y el número NO sale del segmento: sale del `code` del evolutivo. Los dos se
  # parecen desde que el segmento es un slug, y son cosas distintas.
  test "el numero no se saca del segmento de la clave" do
    parsed = Artifacts::Key.parse!("artifacts://matrix-interna/rediseno-interfaz/spec-042/v1.md")

    assert_raises(ArgumentError) { Artifacts::Key.number_from_initiative(parsed.initiative) }
  end

  test "la raiz del evolutivo es lo que publica la etapa 12" do
    assert_equal "artifacts://vivla/ev-009",
                 Artifacts::Key.prefix_for(client: "vivla", initiative: "ev-009")
  end

  test "un codigo de evolutivo invalido se rechaza" do
    assert_raises(ArgumentError) { Artifacts::Key.number_from_initiative("proj-2291") }
  end
end
