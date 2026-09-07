require "test_helper"

# Una ejecución de agente. Lo que se prueba aquí es **el índice único parcial**,
# que es lo único de este modelo que no está en Ruby: vive en Postgres, y lo que
# excluye lo dice con un entero escrito a mano.
class AgentRunTest < ActiveSupport::TestCase
  setup { @initiative = build_initiative }

  # ── El candado ────────────────────────────────────────────────────────────

  test "no puede haber dos ejecuciones vivas del mismo par" do
    live(agent: :tank, purpose: :context)

    assert_raises(ActiveRecord::RecordNotUnique) do
      live(agent: :tank, purpose: :context)
    end
  end

  test "pero sí dos del mismo agente con propósitos distintos" do
    # Es la razón de que `purpose` esté en el índice: SERAPH interviene dos veces
    # por ciclo y sin la distinción no podría verificar tras haber escrito el DoD.
    live(agent: :seraph, purpose: :dod_pass)

    assert_nothing_raised { live(agent: :seraph, purpose: :verification) }
  end

  test "y una terminada no bloquea la siguiente" do
    live(agent: :tank, purpose: :context).update!(status: :ok)

    assert_nothing_raised { live(agent: :tank, purpose: :context) }
  end

  # ── La excepción de B9 ────────────────────────────────────────────────────

  # Dos turnos simultáneos no son un error: son dos preguntas de la misma
  # persona, y las dos valen. Y sobre todo, un turno corre DENTRO de la petición:
  # una que muera por timeout de Puma dejaría un `running` eterno que bloquearía
  # todos los turnos siguientes de ese evolutivo, sin forma de desatascarlo.
  test "los turnos de entrevista sí pueden solaparse" do
    live(agent: :arquitecto, purpose: :interview)

    assert_nothing_raised { live(agent: :arquitecto, purpose: :interview) }
    assert_equal 2, @initiative.agent_runs.live.count
  end

  # El cierre del acta NO es un turno: publica un artefacto, y publicar dos veces
  # a la vez es exactamente lo que el índice existe para impedir.
  test "pero el cierre del acta no, porque publica" do
    live(agent: :arquitecto, purpose: :requirements)

    assert_raises(ActiveRecord::RecordNotUnique) do
      live(agent: :arquitecto, purpose: :requirements)
    end
  end

  # ⚠ EL TEST QUE SOSTIENE LA MIGRACIÓN. El índice excluye `purpose <> 7` con el
  # entero escrito a mano —una cláusula `WHERE` de Postgres no puede leer un enum
  # de Ruby—, así que reordenar el enum haría que excluyera otro propósito en
  # silencio. Aquí se fija el número y se comprueba que el índice dice lo que
  # creemos.
  test "y el 7 del índice es interview, no otro propósito" do
    assert_equal 7, AgentRun.purposes["interview"]

    condicion = ActiveRecord::Base.connection.indexes("agent_runs")
                                  .find { |index| index.name == "idx_agent_runs_one_live" }
                                  .where

    assert_includes condicion, "purpose <> 7"
  end

  private
    def live(agent:, purpose:)
      AgentRun.create!(initiative: @initiative, agent: agent, purpose: purpose,
                       iteration: @initiative.iteration, status: :running,
                       code: "#{agent}/#{purpose}-#{SecureRandom.hex(4)}",
                       started_at: Time.current)
    end
end
