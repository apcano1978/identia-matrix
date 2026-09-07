require "test_helper"

# INVARIANTE 10 · Ningún agente lee ni cita material de otro PROYECTO.
#
# Es obligación contractual, así que es restricción del MODELO y no filtro de la
# vista: una vista se esquiva desde una consola.
#
# ── La frontera se mudó en F11, y es MÁS ESTRECHA ───────────────────────────
#
# Hasta F11 decía «de otro cliente». Dos clientes no comparten proyecto, así que
# **todo lo que era legal lo sigue siendo** —por eso la migración fue segura— y
# además un proyecto deja de ver el material de otro proyecto del mismo cliente.
# Lo único que se prohíbe es algo que antes pasaba inadvertido.
#
# La excepción, y no es un resto por limpiar: los DOCUMENTOS y las REUNIONES
# siguen acotándose por cliente, porque son la proyección de solo lectura de
# platform y llegan sin ninguna noción de proyecto de matrix. Su acotado por
# evolutivo lo hace `initiative_sources`. Está razonado en la cabecera de
# `Citations::Resolve`.
class NoAgentCrossesTheProjectBoundaryTest < ActiveSupport::TestCase
  test "un evolutivo no puede cruzar el repositorio de otro cliente" do
    link = InitiativeRepository.new(
      initiative: build_initiative(client: build_client(slug: "vivla")),
      repository: build_repository(client: build_client(slug: "caser")))

    assert_not link.valid?
    assert_includes link.errors.attribute_names, :repository
  end

  # LO QUE F11 AÑADE, y lo que demuestra el estrechamiento.
  test "ni el de otro proyecto del mismo cliente" do
    cliente = build_client(slug: "vivla")
    segundo = Project.create!(platform_client: cliente, slug: "vivla-dos",
                              name: "El segundo", opened_at: Time.current)

    link = InitiativeRepository.new(
      initiative: build_initiative(client: cliente),
      repository: build_repository(project: segundo, name: "booking-core"))

    assert_not link.valid?
  end

  # Y la misma frontera en la resolución de citas, que es por donde un agente
  # llegaría al material.
  test "una cita no resuelve contra el artefacto de otro proyecto del mismo cliente" do
    cliente = build_client(slug: "vivla")
    ajeno = build_artifact(initiative: build_initiative(client: cliente), kind: :spec)
    segundo = Project.create!(platform_client: cliente, slug: "vivla-dos",
                              name: "El segundo", opened_at: Time.current)

    resuelto = Citations::Resolve.call(
      Citations::Parse.call!("[src:spec/#{ajeno.code}]"), project: segundo)

    assert_nil resuelto, "el artefacto es del primer proyecto, no del segundo"
  end

  test "el contexto que arma el runtime solo lleva repositorios de su proyecto" do
    DesignSeed.call
    initiative = Initiative.find_by!(code: "ev-031")
    run = AgentRun.create!(initiative: initiative, agent: :tank,
                           purpose: :context, code: "tank/frontera",
                           status: :running)

    payload = Runtime::Request.for(run).payload
    names = payload.dig("config", "repositories").map { |r| r["name"] }

    assert_equal initiative.repositories.pluck(:name).sort, names.sort
    assert_equal "vivla", payload.dig("config", "client", "slug")
  end

  # MATERIAL NUEVO CRUZANDO POR PRIMERA VEZ (B8). El ARQUITECTO recibe el acta
  # en curso, y un acta son preguntas de negocio: exactamente lo que no puede
  # salir de su proyecto.
  #
  # La consulta sale de la asociación del EVOLUTIVO, que es más estrecho todavía
  # que el proyecto: dos evolutivos del mismo proyecto tampoco comparten acta.
  test "y el acta que recibe el ARQUITECTO es solo la de su evolutivo" do
    cliente = build_client(slug: "vivla")
    suyo = build_initiative(client: cliente)
    ajeno = build_initiative(project: suyo.project)

    decision(suyo, 1, "¿La mía?")
    decision(ajeno, 1, "¿La del otro evolutivo del mismo proyecto?")

    run = AgentRun.create!(initiative: suyo, agent: :arquitecto,
                           purpose: :interview, code: "arquitecto/frontera",
                           status: :running)
    preguntas = Runtime::Request.for(run).payload
                                .dig("config", "decisions").map { |d| d["question"] }

    assert_equal [ "¿La mía?" ], preguntas
  end

  # Y los demás agentes no la reciben en absoluto: `MATERIAL` es una lista de
  # concesiones, y lo que no aparece no es un hueco, es la frontera.
  test "y ningún otro agente la recibe" do
    initiative = build_initiative
    decision(initiative, 1, "¿Algo?")

    (AgentRun.agents.keys - [ "arquitecto" ]).each do |agent|
      run = AgentRun.create!(initiative: initiative, agent: agent,
                             purpose: Pipeline::STAGE_WORK.values
                                        .find { |w| w[:agent] == agent }[:purpose],
                             code: "#{agent}/sin-acta", status: :running)

      assert_nil Runtime::Request.for(run).payload.dig("config", "decisions"),
                 "#{agent} no tiene por qué ver el acta"
    end
  end

  test "la frontera se puede comprobar con un where, sin navegar asociaciones" do
    # Desnormalizado a propósito: tiene que ser barato de imponer en cada
    # consulta, no una condición que se olvide en la que corre pocas veces.
    #
    # Mientras dure la mudanza conviven las dos columnas; al contraer se retira
    # `platform_client_id` de estas cinco y esta comprobación se queda sola.
    %w[repositories initiatives escalations human_notes artifacts]
      .each do |table|
      assert_includes ActiveRecord::Base.connection.columns(table).map(&:name),
                      "project_id", "#{table} no lleva el proyecto"
    end
  end

  test "en el seed, ningún artefacto pertenece a un proyecto distinto del de su evolutivo" do
    DesignSeed.call

    crossed = Artifact.includes(:initiative).reject do |artifact|
      artifact.project_id == artifact.initiative.project_id
    end

    assert_empty crossed
  end

  private
    def decision(initiative, ordinal, question)
      initiative.decisions.create!(project: initiative.project, ordinal: ordinal,
                                   question: question)
    end
end
