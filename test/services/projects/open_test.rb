# frozen_string_literal: true

require "test_helper"

# El alta de un proyecto propio. Lo que se prueba aquí no es que cree una fila:
# es **que el nombre corto no pueda salir mal**, porque se congela al crear y va
# dentro de las claves de todos los artefactos que el proyecto llegue a producir.
class Projects::OpenTest < ActiveSupport::TestCase
  test "abre un proyecto propio, sin cliente detrás" do
    proyecto = Projects::Open.call(slug: "matrix-interna",
                                   name: "Matrix interna", actor: "antonio")

    assert proyecto.own?, "un alta manual no puede tener cliente"
    assert_equal "matrix-interna", proyecto.slug
    assert_equal "Matrix interna", proyecto.name
    assert proyecto.opened_at.present?
  end

  test "y deja constancia, con el proyecto y sin cliente" do
    proyecto = Projects::Open.call(slug: "radar-ofertas", name: "Radar",
                                   actor: "antonio")
    evento = Event.where(kind: "project_opened").sole

    assert_equal proyecto, evento.project
    assert_nil evento.platform_client, "no hay ninguno, y no se inventa"
    assert_equal "antonio", evento.actor
  end

  test "el nombre corto se normaliza a minúsculas y sin espacios de sobra" do
    proyecto = Projects::Open.call(slug: "  Radar-Ofertas  ", name: "Radar",
                                   actor: "antonio")

    assert_equal "radar-ofertas", proyecto.slug
  end

  # Las cuatro formas de escribirlo mal, y las cuatro se rechazan con palabras.
  # Un `RecordInvalid` diría «Slug no es válido», que no explica qué arreglar.
  test "un nombre corto que no case con la gramática de citas se rechaza" do
    [ "Radar Ofertas", "radar_ofertas", "radar.ofertas", "radaróferta",
      "-radar", "radar--ofertas" ].each do |malo|
      error = assert_raises(Projects::Open::Refused, "debería rechazar #{malo.inspect}") do
        Projects::Open.call(slug: malo, name: "Radar", actor: "antonio")
      end

      assert_match "claves de artefacto", error.message
    end
  end

  # El tope que no cabe en el modelo: el slug de un proyecto de cliente se hereda
  # de la razón social y `parameterize` no trunca, así que validarlo en `Project`
  # habría reventado el backfill. Es una regla de ESTE formulario.
  test "y uno de más de cuarenta caracteres tampoco, aunque el modelo lo admita" do
    largo = "a" * (Projects::Open::MAX_SLUG + 1)

    error = assert_raises(Projects::Open::Refused) do
      Projects::Open.call(slug: largo, name: "Radar", actor: "antonio")
    end

    assert_match "40 caracteres", error.message
    assert Project.new(slug: largo, name: "x", opened_at: Time.current).valid?,
           "el tope es del formulario: el modelo tiene que seguir admitiéndolo"
  end

  test "sin nombre corto o sin título no se abre nada" do
    assert_raises(Projects::Open::Refused) do
      Projects::Open.call(slug: "", name: "Radar", actor: "antonio")
    end
    assert_raises(Projects::Open::Refused) do
      Projects::Open.call(slug: "radar", name: "  ", actor: "antonio")
    end

    assert_equal 0, Project.count
  end

  # La unicidad la defiende el índice, no el servicio: es el único sitio donde
  # dos altas simultáneas no pueden colarse entre la comprobación y la escritura.
  test "un nombre corto repetido lo rechaza la tabla, no una comprobación previa" do
    build_own_project(slug: "radar-ofertas")

    assert_raises(ActiveRecord::RecordInvalid) do
      Projects::Open.call(slug: "radar-ofertas", name: "Otro", actor: "antonio")
    end
  end

  # Y no puede chocar con el de un cliente por accidente: comparten espacio de
  # nombres porque comparten el primer segmento de las claves de artefacto.
  test "ni uno que ya use un cliente, que viven en el mismo espacio de nombres" do
    build_client(slug: "vivla")

    assert_raises(ActiveRecord::RecordInvalid) do
      Projects::Open.call(slug: "vivla", name: "Vivla interna", actor: "antonio")
    end
  end

  test "nada se escribe si el evento falla: es una transacción" do
    Event.stub(:create!, ->(*) { raise ActiveRecord::RecordInvalid.new(Event.new) }) do
      assert_raises(ActiveRecord::RecordInvalid) do
        Projects::Open.call(slug: "radar-ofertas", name: "Radar", actor: "antonio")
      end
    end

    assert_nil Project.find_by(slug: "radar-ofertas")
  end
end
