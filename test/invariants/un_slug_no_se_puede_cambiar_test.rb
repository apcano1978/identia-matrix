# frozen_string_literal: true

require "test_helper"

# EL SLUG SE ELIGE UNA VEZ Y NO SE MUEVE.
#
# No es una preferencia de estilo. Son ya TRES los slugs congelados del sistema —
# el del proyecto, el del evolutivo y, desde F12, el de un documento subido— y
# los tres por la misma razón. El del proyecto es el primer segmento de la clave
# de todos sus artefactos y el del evolutivo es el segundo:
#
#   artifacts://identia-interno/rediseno-interfaz/spec-042/v1.md
#
# Esas claves viven en un bucket sin borrado y dentro de citas escritas en
# markdown inmutable. Cambiar un slug después no renombra nada: deja huérfanas
# todas las claves ya emitidas y convierte en mentira cada cita que las nombra.
#
# Es la misma regla que `Platform::Projection::FROZEN` aplica al slug de cliente
# desde F8, y por la misma razón.
class UnSlugNoSePuedeCambiarTest < ActiveSupport::TestCase
  test "el de un proyecto" do
    project = build_own_project(slug: "identia-interno")

    assert_raises(ActiveRecord::ReadOnlyRecord) { project.update!(slug: "otro") }
    assert_equal "identia-interno", project.reload.slug
  end

  test "y el de un evolutivo" do
    initiative = build_initiative(slug: "precio-festivos")

    assert_raises(ActiveRecord::ReadOnlyRecord) { initiative.update!(slug: "otro") }
    assert_equal "precio-festivos", initiative.reload.slug
  end

  # Y el de un documento subido, desde F12: se cita como
  # `[src:doc/acta-precios#p2]` y esa cita viaja dentro de artefactos inmutables
  # igual que las otras dos.
  test "y el de un documento subido a un proyecto" do
    document = build_project_document(slug: "acta-precios")

    assert_raises(ActiveRecord::ReadOnlyRecord) { document.update!(slug: "otra") }
    assert_equal "acta-precios", document.reload.slug
  end

  # Lo que SÍ se puede cambiar, para que quede escrito de qué va la regla: el
  # título es lo que se lee, y no lo lleva dentro ninguna clave.
  test "el titulo no: eso se muestra, no se cita" do
    initiative = build_initiative(slug: "precio-festivos")
    initiative.update!(title: "Otro título")

    assert_equal "Otro título", initiative.reload.title
    assert_equal "precio-festivos", initiative.slug
  end

  # La guarda que impide que los dos espacios de nombres se solapen. Sin ella,
  # `[src:spec/spec-031]` podría nombrar el código de un artefacto O el nombre de
  # un evolutivo, y `Citations::Resolve` tendría que elegir en silencio.
  test "un evolutivo no puede llamarse como un codigo de artefacto" do
    %w[spec-031 dod-014 pkg-045 close-002 arquitecto-031 guia-pruebas-031].each do |malo|
      initiative = Initiative.new(project: build_own_project, code: "ev-777",
                                  slug: malo, title: "x", opened_at: Time.current)

      refute_predicate initiative, :valid?, "#{malo} no debería valer como nombre"
      assert_includes initiative.errors.attribute_names, :slug
    end
  end

  # Y `ev-031` sí, porque es lo que deja el relleno de la migración: si no valiera,
  # ningún evolutivo anterior a F11 podría guardarse.
  test "pero si puede llamarse como su propio codigo" do
    assert_predicate build_initiative(code: "ev-031", slug: "ev-031"), :persisted?
  end
end
