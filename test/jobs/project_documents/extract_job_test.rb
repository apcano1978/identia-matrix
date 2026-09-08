# frozen_string_literal: true

require "test_helper"

# El job no hace nada por su cuenta: carga la fila y delega. Lo que se prueba
# aquí es que esa delegación ocurre y que no revienta con una fila que ya no
# está — que es todo lo que un job debe garantizar.
class ProjectDocuments::ExtractJobTest < ActiveJob::TestCase
  test "extrae el documento que le nombran" do
    document = build_project_document(content: "# Arranque\n\nEl texto.")

    ProjectDocuments::ExtractJob.perform_now(document.id)

    assert_equal "# Arranque\n\nEl texto.", document.reload.body
    assert_predicate document, :citable?
  end

  # Si el documento ya no está, no hay nada que extraer: se descarta en vez de
  # reintentar contra una fila que no existe.
  test "y descarta el que ya no existe, sin reintentarlo" do
    assert_nothing_raised { ProjectDocuments::ExtractJob.perform_now(-1) }
  end

  # La cola importa: `low` tiene concurrencia 1 y es del latido de artefactos,
  # que corre solo y sin nadie mirando. Esto lo espera alguien delante de una
  # pantalla —el rediseño pinta «extrayendo texto»—.
  test "va en la cola de siempre, no en la del latido" do
    assert_equal "default", ProjectDocuments::ExtractJob.new.queue_name
  end
end
