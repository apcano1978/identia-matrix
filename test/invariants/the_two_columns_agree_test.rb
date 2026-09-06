# frozen_string_literal: true

require "test_helper"

# ⚠ ANDAMIO TEMPORAL. SE BORRA AL CONTRAER, Y NO SE CONSERVA POR COSTUMBRE.
#
# La mudanza de la raíz —de `Platform::Client` a `Project`— va en tres commits:
# expandir, migrar los lectores, contraer. Este test solo tiene sentido en el
# tramo del medio, mientras las dos columnas conviven, y es la única red que
# existe ahí: comprueba que **todo lo que se escribe por un camino real llega con
# las dos columnas puestas y diciendo lo mismo**.
#
# Sin él, una ruta de escritura que se olvidara de `project_id` no daría ningún
# síntoma hasta el `null: false` del contrar — es decir, en la migración, sobre
# datos de producción y con el despliegue a medias.
#
# Cuando `platform_client_id` desaparezca de las siete tablas, este fichero se
# borra: comparar una columna consigo misma no afirma nada.
class TheTwoColumnsAgreeTest < ActiveSupport::TestCase
  # Las ocho nativas. `events` conserva las dos para siempre —un evento de
  # sincronización es del cliente y no de ningún proyecto—, pero cuando lleva
  # proyecto tiene que ser el del cliente.
  TABLES = [ AgentConfig, Artifact, Escalation, Event,
             HumanNote, Initiative, Repository, RepositoryCredential ].freeze

  test "cada fila que tiene cliente tiene tambien su proyecto, y es el mismo" do
    ejercitar_las_escrituras_reales

    discrepan = TABLES.flat_map do |modelo|
      modelo.where.not(platform_client_id: nil).filter_map do |fila|
        next "#{modelo.name}##{fila.id} tiene cliente y no proyecto" if fila.project_id.nil?
        next if fila.project.platform_client_id == fila.platform_client_id

        "#{modelo.name}##{fila.id} apunta al proyecto de otro cliente"
      end
    end

    assert_empty discrepan, <<~MSG
      Una ruta de escritura no está poniendo `project_id`. Eso no da síntoma hasta
      el `null: false` del contraer, que ocurre en una migración sobre datos
      reales. Arréglalo en la escritura, no aquí.

      #{discrepan.join("\n  ")}
    MSG
  end

  test "el andamio esta mirando algo" do
    ejercitar_las_escrituras_reales

    # La misma disciplina que SourceScan: un test que recorre un conjunto vacío
    # pasa en verde sin comprobar nada, y ese es justo el fallo que este test
    # existe para evitar en otro sitio.
    filas = TABLES.sum { |modelo| modelo.where.not(platform_client_id: nil).count }

    assert_operator filas, :>=, 6,
                    "el andamio no encontró filas con cliente: no está comprobando nada"
  end

  private

    # Por los caminos de verdad, no con `create!` a pelo: lo que se quiere
    # comprobar es que las RUTAS DE ESCRITURA ponen la columna, y un `create!`
    # dentro del test la pondría por su cuenta y no probaría nada.
    def ejercitar_las_escrituras_reales
      cliente = build_client(slug: "vivla")
      repositorio = build_repository(client: cliente, name: "booking-core")

      initiative = Initiatives::Open.call(
        client: cliente, title: "Precio en festivos",
        repositories: [ repositorio ], actor: "antonio")

      publish_artifact(initiative: initiative, kind: :dossier)
      Pipeline::Escalate.call(initiative: initiative, reason: :inconclusive_environment)
    end
end
