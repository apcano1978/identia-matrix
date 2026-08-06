require "test_helper"

# INVARIANTE 10 · Ningún agente lee ni cita material de otro cliente.
#
# Es obligación contractual, así que es restricción del MODELO y no filtro de la
# vista: una vista se esquiva desde una consola.
class NoAgentCrossesTheClientBoundaryTest < ActiveSupport::TestCase
  test "un evolutivo no puede cruzar el repositorio de otro cliente" do
    link = InitiativeRepository.new(
      initiative: build_initiative(client: build_client(slug: "vivla")),
      repository: build_repository(client: build_client(slug: "caser")))

    assert_not link.valid?
    assert_includes link.errors.attribute_names, :repository
  end

  test "el contexto que arma el runtime solo lleva repositorios de su cliente" do
    DesignSeed.call
    initiative = Initiative.find_by!(code: "ev-031")
    run = AgentRun.create!(initiative: initiative, agent: :tank,
                           purpose: :context, code: "tank/frontera",
                           status: :running)

    payload = Runtime::Request.for(run).payload
    names = payload.dig("context", "repositories").map { |r| r["name"] }

    assert_equal initiative.repositories.pluck(:name).sort, names.sort
    assert_equal "vivla", payload.dig("context", "client", "slug")
  end

  test "la frontera se puede comprobar con un where, sin navegar asociaciones" do
    # Desnormalizado a propósito: tiene que ser barato de imponer en cada
    # consulta, no una condición que se olvide en la que corre pocas veces.
    %w[repositories initiatives escalations human_notes artifacts]
      .each do |table|
      assert_includes ActiveRecord::Base.connection.columns(table).map(&:name),
                      "platform_client_id", "#{table} no lleva el cliente"
    end
  end

  test "en el seed, ningún artefacto pertenece a un cliente distinto del de su evolutivo" do
    DesignSeed.call

    crossed = Artifact.includes(:initiative).reject do |artifact|
      artifact.platform_client_id == artifact.initiative.platform_client_id
    end

    assert_empty crossed
  end
end
