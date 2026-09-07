require "test_helper"

# Reconciliar hallazgos contra el acta. La propiedad que se defiende aquí es que
# **el ordinal no se mueve**: está dentro de citas emitidas en markdown que nadie
# puede reescribir.
class Decisions::ApplyTest < ActiveSupport::TestCase
  setup { @initiative = build_initiative }

  test "un hallazgo sin referencia crea una decisión con el siguiente ordinal" do
    aplicadas = apply([ finding(statement: "¿Quién decide el precio?") ])

    assert_equal 1, aplicadas.sole.ordinal
    assert_predicate aplicadas.sole, :status_open?
    assert_equal "¿Quién decide el precio?", aplicadas.sole.question
  end

  test "y los siguientes siguen contando, sin empezar de nuevo" do
    apply([ finding(statement: "Una") ])
    aplicadas = apply([ finding(statement: "Dos"), finding(statement: "Tres") ])

    assert_equal [ 2, 3 ], aplicadas.map(&:ordinal)
    assert_equal 3, @initiative.decisions.count
  end

  test "un hallazgo con referencia actualiza esa decisión, no crea otra" do
    apply([ finding(statement: "¿Quién decide el precio?") ])

    apply([ finding(reference: "1", statement: "¿Quién decide el precio?",
                    answer: "pricing-svc, y el resto consulta.", status: "closed",
                    evidence: "[src:meet/2026-05-02@22:40]") ])

    decision = @initiative.decisions.sole

    assert_predicate decision, :status_closed?
    assert_equal "pricing-svc, y el resto consulta.", decision.answer
    assert_equal "[src:meet/2026-05-02@22:40]", decision.source_citation
  end

  # La razón de reconciliar en vez de reemplazar: si el turno omite una decisión,
  # esa se queda como estaba y su ordinal no se lo lleva otra.
  test "lo que el turno no menciona se queda como estaba, con su número" do
    apply([ finding(statement: "Una"), finding(statement: "Dos") ])

    apply([ finding(reference: "2", statement: "Dos", answer: "Sí.",
                    status: "closed") ])

    assert_equal [ [ 1, "open" ], [ 2, "closed" ] ],
                 @initiative.decisions.by_ordinal.pluck(:ordinal, :status)
  end

  test "descartada es un estado, no una cerrada con respuesta negativa" do
    aplicadas = apply([ finding(statement: "¿Entra temporada alta?",
                                answer: "Fuera de alcance.", status: "discarded") ])

    assert_predicate aplicadas.sole, :status_discarded?
  end

  test "los hallazgos que no son decisiones se ignoran, no revientan" do
    aplicadas = apply([ { "kind" => "advisory", "statement" => "Ojo con esto" },
                        finding(statement: "¿Y esto?") ])

    assert_equal 1, aplicadas.size
    assert_equal 1, @initiative.decisions.count
  end

  test "la ejecución que levantó cada decisión queda registrada" do
    run = build_run(initiative: @initiative, agent: :arquitecto,
                    purpose: :interview)
    aplicadas = apply([ finding(statement: "¿Quién decide?") ], run: run)

    assert_equal run, aplicadas.sole.raised_by_run
  end

  # ── Las dos negativas ─────────────────────────────────────────────────────

  test "una referencia que no existe se rechaza en vez de crear una decisión" do
    error = assert_raises(Decisions::Apply::Refused) do
      apply([ finding(reference: "7", statement: "¿Y esta?") ])
    end

    assert_match "no hay ninguna decisión 7", error.message
    assert_equal 0, @initiative.decisions.count
  end

  # La misma raya que la guarda del modelo, comprobada ANTES de empezar la
  # tanda: sin esto el primer hallazgo nuevo se habría creado —crear no pasa por
  # `before_update`— y el primero que actualizara habría reventado a mitad.
  test "y con el acta publicada no se toca nada, ni siquiera lo nuevo" do
    apply([ finding(statement: "Una") ])
    publish_artifact(initiative: @initiative, kind: :acta)

    error = assert_raises(Decisions::Apply::Refused) do
      apply([ finding(statement: "Dos") ])
    end

    assert_match "es otro delta", error.message
    assert_equal 1, @initiative.decisions.count
  end

  private
    def apply(findings, run: nil)
      Decisions::Apply.call(initiative: @initiative, findings: findings, run: run)
    end

    def finding(statement:, reference: nil, answer: nil, status: nil,
                evidence: nil)
      { "kind" => "decision", "reference" => reference, "statement" => statement,
        "answer" => answer, "status" => status, "evidence" => evidence }
    end
end
