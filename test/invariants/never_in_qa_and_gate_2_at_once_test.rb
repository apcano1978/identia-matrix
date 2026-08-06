require "test_helper"

# INVARIANTE 11 · Un evolutivo no puede estar en ciclo de QA y en GATE 2 a la
# vez.
#
# No se vigila: es IMPOSIBLE. Hay una sola `current_stage`, y una sola fila de
# etapa abierta. Convertir una regla en una imposibilidad estructural es la
# diferencia entre un invariante y una buena intención.
class NeverInQaAndGate2AtOnceTest < ActiveSupport::TestCase
  test "solo hay una etapa actual, y es una columna" do
    assert_includes Initiative.column_names, "current_stage"
    assert_not_includes Initiative.column_names, "current_stages"
  end

  test "no hay guía de pruebas sobre un informe que devolvió" do
    returned = build_report(outcome: :returned)
    guide = TestGuide.new(initiative: returned.initiative,
                          verification_report: returned, code: "guia-x")

    assert_not guide.valid?
  end

  test "después de cualquier bifurcación queda una sola fila abierta" do
    initiative = place(build_initiative, :morfeo)

    Pipeline::SendBack.call(initiative: initiative, to: :neo)
    assert_equal 1, open_entries(initiative)

    place(initiative, :gate_2)
    Pipeline::SendBack.call(initiative: initiative, to: :neo, actor: "Antonio")
    assert_equal 1, open_entries(initiative)

    # Un flujo detenido no tiene NINGUNA abierta: la etapa queda cerrada como
    # `escalated` y no se entra en otra hasta que alguien reinicie.
    Pipeline::Escalate.call(initiative: initiative, reason: "qa_cycles_exhausted")
    assert_equal 0, open_entries(initiative)
    assert_predicate initiative.reload, :status_escalated?
  end

  test "y también después de recorrer el pipeline entero, en las seis variantes" do
    DesignSeed.call

    PipelineWalk::VARIANTS.each_key do |variant|
      initiative = PipelineWalk.call(code: "ev-8#{variant.sum % 90 + 10}",
                                     variant: variant).initiative

      assert_operator open_entries(initiative), :<=, 1,
                      "#{variant} dejó dos etapas abiertas"
    end
  end

  test "el seed tampoco deja ninguno con dos" do
    DesignSeed.call

    Initiative.find_each do |initiative|
      assert_operator open_entries(initiative), :<=, 1, initiative.code
    end
  end

  private
    def open_entries(initiative)
      initiative.stage_entries.where(exited_at: nil).count
    end
end
