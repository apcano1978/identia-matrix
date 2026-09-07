# frozen_string_literal: true

require "test_helper"

# El proyecto es la raíz del modelo desde F11, y la frontera del invariante 10.
class ProjectTest < ActiveSupport::TestCase
  test "un proyecto de cliente y uno propio se distinguen por la clave, no por un tipo" do
    cliente = build_client(slug: "vivla")
    de_cliente = project_for(cliente)
    propio = build_own_project(slug: "matrix-interna")

    assert_predicate de_cliente, :for_client?
    refute_predicate de_cliente, :own?

    assert_predicate propio, :own?
    refute_predicate propio, :for_client?

    # Y no hay ninguna columna que pueda discrepar de eso.
    refute_includes Project.column_names, "kind"
  end

  test "el slug se congela al crear" do
    project = build_own_project(slug: "matrix-interna")

    error = assert_raises(ActiveRecord::ReadOnlyRecord) do
      project.update!(slug: "otro-nombre")
    end

    assert_match "las claves de artefacto dependen de él", error.message
    assert_equal "matrix-interna", project.reload.slug
  end

  test "el nombre si se puede cambiar" do
    project = build_own_project(slug: "matrix-interna")
    project.update!(name: "Matrix, por dentro")

    assert_equal "Matrix, por dentro", project.reload.name
  end

  test "dos proyectos no comparten slug" do
    build_own_project(slug: "matrix-interna")

    assert_raises(ActiveRecord::RecordInvalid) do
      build_own_project(slug: "matrix-interna")
    end
  end

  test "el slug tiene que casar con la gramatica de citas" do
    [ "Matrix-Interna", "matrix_interna", "matrix interna", "-matrix", "matrix-" ].each do |malo|
      project = Project.new(slug: malo, name: "X", opened_at: Time.current)

      refute_predicate project, :valid?, "#{malo.inspect} no debería valer como slug"
    end
  end

  # No es un descuido: el slug se HEREDA del cliente, y los de cliente los deriva
  # `Platform::Slug` con `parameterize`, que no trunca. Un tope aquí reventaría el
  # alta de un cliente con razón social larga, y truncar rompería las claves de
  # artefacto que ya lo llevan dentro. El tope de cuarenta vive en el formulario.
  test "un slug largo heredado del cliente no se rechaza" do
    largo = "telefonica-soluciones-de-informatica-y-comunicaciones-de-espana"

    assert_operator largo.length, :>, 40
    assert_predicate build_own_project(slug: largo), :persisted?
  end

  # El slug es el PRIMER SEGMENTO de la clave de todos los artefactos del
  # proyecto, y esas claves viven en un bucket sin borrado y dentro de citas ya
  # escritas. Cambiarlo no renombra nada: deja huérfano todo lo emitido.
  #
  # `FrozenSlug` estaba incluido desde B3 y nadie lo afirmaba sobre `Project`.
  # Desde B7b hay un formulario que crea proyectos, así que la guarda deja de ser
  # teórica: alguien puede querer «corregir» el nombre corto que escribió mal.
  test "el slug se congela al crear y no se puede corregir despues" do
    proyecto = build_own_project(slug: "matrix-intena")

    error = assert_raises(ActiveRecord::ReadOnlyRecord) do
      proyecto.update!(slug: "matrix-interna")
    end

    assert_match "las claves de artefacto dependen de él", error.message
    assert_equal "matrix-intena", proyecto.reload.slug
  end

  # El título sí es solo un rótulo… y tampoco se edita, porque matrix no tiene
  # ningún `update` de proyecto. Lo que el modelo permite y la aplicación no
  # ofrece conviene tenerlo separado: la guarda de arriba es del dominio, la
  # ausencia de ruta es una decisión de producto y vive en la lista blanca.
  test "pero el nombre no está congelado: lo que no hay es por dónde cambiarlo" do
    proyecto = build_own_project

    assert proyecto.update(name: "Otro nombre"),
           "el modelo no lo prohíbe; la aplicación no ofrece ninguna ruta"
    assert_empty Rails.application.routes.routes.select { |route|
      route.defaults[:controller] == "projects" &&
        %w[update edit destroy].include?(route.defaults[:action])
    }
  end

  test "un proyecto del que cuelga trabajo no se puede borrar" do
    initiative = build_initiative

    assert_raises(ActiveRecord::DeleteRestrictionError) do
      initiative.project.destroy!
    end
  end
end
