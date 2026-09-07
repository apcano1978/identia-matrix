require "test_helper"

# Un turno de la conversación. Lo que se prueba aquí es **que ocurre dentro de la
# petición** y que lo que escribe la persona queda citable — las dos cosas que
# distinguen a este agente de los otros seis.
class Actas::TurnTest < ActiveSupport::TestCase
  setup do
    @initiative = build_initiative
    place(@initiative, :need)
    @author = build_platform_user
  end

  test "deja una nota citable con lo que escribió la persona" do
    resultado = turn("Puede cachear disponibilidad, no precio.")

    assert_equal "Puede cachear disponibilidad, no precio.", resultado.note.body
    assert_equal @author, resultado.note.author_user
    assert_equal @initiative.project, resultado.note.project

    # Citable de verdad: la gramática tiene que aceptar el código que se compuso.
    _valid, invalid = Citations::Parse.scan(resultado.note.citation)

    assert_empty invalid
  end

  # Es lo que hace que el gasto del ARQUITECTO se contabilice como el de
  # cualquier otro agente: no hay una segunda forma de hablar con el brain.
  test "y una fila de ejecución con su consumo, como cualquier otro agente" do
    resultado = turn("Lo pregunto al cliente esta semana.")

    assert_predicate resultado.run, :agent_arquitecto?
    assert_predicate resultado.run, :purpose_interview?
    assert_predicate resultado.run, :ok?
    assert_equal "arquitecto/#{@initiative.code}-interview-1", resultado.run.code
  end

  test "las decisiones del turno quedan aplicadas, con su ordinal" do
    resultado = turn("Adelante.")

    assert_equal [ 1, 2, 3 ], resultado.decisions.map(&:ordinal)
    assert_equal 3, @initiative.decisions.count
    assert_equal resultado.run, @initiative.decisions.first.raised_by_run
  end

  # LA PROPIEDAD DEL BLOQUE: el turno corre en la petición y no encola nada.
  # Un turno encolado no es un turno — la persona estaría esperando a una cola
  # entre su pregunta y la respuesta.
  #
  # Se afirma por el EFECTO y no espiando la cola: al volver, la ejecución ya
  # terminó. Una encolada habría vuelto en `queued`, sin `finished_at` y sin
  # decisiones que enseñar.
  test "ocurre dentro de la petición: al volver ya está hecho" do
    resultado = turn("Contesto ahora.")

    assert_predicate resultado.run, :ok?
    assert resultado.run.finished_at.present?
    assert_predicate resultado.decisions, :any?
  end

  # Y por el código, que es lo que impide que alguien lo «arregle» encolándolo:
  # el día que este servicio llame al job, el turno deja de ser una conversación
  # sin que ningún test de efecto se entere —el job corre en línea en test—.
  test "y ningún servicio del acta encola nada" do
    # Sin los comentarios: esta cabecera NOMBRA a `Agents::RunJob` para explicar
    # por qué no lo usa, y un escaneo del texto crudo se cazaría a sí mismo.
    codigo = Rails.root.glob("app/services/actas/*.rb")
                  .map { |file| file.read.gsub(/^\s*#.*$/, "") }.join

    assert_no_match(/perform_later|RunJob/, codigo,
                    "un turno encolado no es un turno")
  end

  test "dos turnos seguidos se pueden, y el segundo ve lo que dejó el primero" do
    turn("Uno.")
    resultado = turn("Dos.")

    assert_equal 2, @initiative.human_notes.count
    assert_equal 6, @initiative.decisions.count
    assert_equal "arquitecto/#{@initiative.code}-interview-2", resultado.run.code
  end

  # No lo impide el índice único —B9 lo abrió para los turnos, a propósito— así
  # que esto comprueba que la apertura funciona de verdad y no solo en el DDL.
  test "y dos turnos vivos a la vez no chocan" do
    AgentRun.create!(initiative: @initiative, agent: :arquitecto,
                     purpose: :interview, iteration: @initiative.iteration,
                     code: "arquitecto/colgado", status: :running,
                     started_at: Time.current)

    assert_nothing_raised { turn("Mientras tanto…") }
  end

  # ── Las negativas ─────────────────────────────────────────────────────────

  test "sin nada escrito no se gasta una llamada al agente" do
    assert_raises(Actas::Turn::Refused) { turn("   ") }

    assert_equal 0, @initiative.agent_runs.count
    assert_equal 0, @initiative.human_notes.count
  end

  # Misma raya que `Decision` y `Decisions::Apply`. Se comprueba ANTES de escribir
  # la nota: dejar constancia de una conversación que no puede continuar sería
  # peor que no dejarla.
  test "cerrada el acta, la conversación no continúa" do
    publish_artifact(initiative: @initiative, kind: :acta)

    error = assert_raises(Actas::Turn::Refused) { turn("¿Y esto?") }

    assert_match "es otro delta", error.message
    assert_equal 0, @initiative.human_notes.count
  end

  # Si el agente revienta a mitad, la fila no se queda en `running`.
  #
  # `Agents::Run` ya marca `failed` ante un `Runtime::Error`; lo que cubre este
  # servicio es TODO LO DEMÁS —un timeout, un fallo de base de datos—, que allí
  # sube sin tocar la fila. Y sin el índice abierto a los turnos, una fila
  # colgada así bloquearía la conversación entera para siempre.
  test "si el turno revienta por algo que no es del brain, su fila no queda viva" do
    Runtime.stub(:run, ->(_) { raise Timeout::Error, "el brain no contestó a tiempo" }) do
      assert_raises(Timeout::Error) { turn("Algo.") }
    end

    assert_equal 0, @initiative.agent_runs.live.count
    assert_predicate @initiative.agent_runs.sole, :failed?
    assert_match "no contestó a tiempo", @initiative.agent_runs.sole.error
  end

  # Lo que pasa DESPUÉS de que el agente conteste bien es otra cosa: la ejecución
  # sí ocurrió y se pagó, así que marcarla fallida sería mentir sobre ella.
  test "pero si falla al aplicar los hallazgos, la ejecución sigue siendo buena" do
    Decisions::Apply.stub(:call, ->(**) { raise Decisions::Apply::Refused, "roto" }) do
      assert_raises(Decisions::Apply::Refused) { turn("Algo.") }
    end

    assert_predicate @initiative.agent_runs.sole, :ok?
  end

  private
    def turn(message)
      Actas::Turn.call(initiative: @initiative, message: message,
                       author: @author)
    end
end
