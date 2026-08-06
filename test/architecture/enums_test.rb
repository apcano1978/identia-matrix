require "test_helper"

# Los enums del modelo no redeclaran lo que F0 ya congeló: lo comprueban.
#
# Redeclararlo sería tener dos listas que dicen lo mismo hasta el día que una se
# toca — y ese día el contrato aceptaría un valor que el modelo rechaza, o al
# revés, sin que nada se ponga rojo.
class EnumsTest < ActiveSupport::TestCase
  test "los propósitos de AgentRun son los del contrato con brain" do
    schema = Contracts.definition(:matrix_brain_agent_result)

    assert_equal schema.dig("properties", "purpose", "enum").sort,
                 AgentRun.purposes.keys.sort
  end

  test "los agentes de AgentRun son los del contrato con brain" do
    schema = Contracts.definition(:matrix_brain_agent_result)

    assert_equal schema.dig("properties", "agent", "enum").sort,
                 AgentRun.agents.keys.sort
    assert_equal AgentRun.agents.keys.sort, AgentConfig.agents.keys.sort
  end

  test "los veredictos son los del contrato con brain" do
    schema = Contracts.definition(:matrix_brain_agent_result)
    contract_verdicts = schema.dig("properties", "findings", "items",
                                   "properties", "verdict", "enum").compact

    assert_equal contract_verdicts.sort, Verdict.results.keys.sort
  end

  test "los tipos de artefacto son los prefijos de Artifacts::Key" do
    assert_equal Artifacts::Key::KINDS.map(&:to_s).sort, Artifact.kinds.keys.sort
  end

  test "los tipos de cita son los nueve de la gramática" do
    assert_equal Citations::Grammar::KINDS.sort, Citation.source_kinds.keys.sort
  end

  test "las doce etapas son las mismas en el evolutivo y en su historial" do
    assert_equal 12, Initiative::STAGES.size
    assert_equal Initiative.current_stages, StageEntry.stages
  end

  test "y las mismas que brain recibe en el contexto de una ejecución" do
    schema = Contracts.definition(:matrix_brain_agent_run)

    assert_equal schema.dig("properties", "context", "properties", "stage", "enum"),
                 Initiative::STAGES
  end

  test "los artefactos previos que viajan a brain son los mismos siete tipos" do
    schema = Contracts.definition(:matrix_brain_agent_run)
    contract_kinds = schema.dig("properties", "context", "properties",
                                "prior_artifacts", "items", "properties",
                                "kind", "enum")

    assert_equal contract_kinds, Artifact.kinds.keys
  end

  test "el estado de etapa es el mismo en el caché y en la fuente" do
    assert_equal Initiative.current_stage_statuses, StageEntry.statuses
  end

  test "cada veredicto tiene su glifo" do
    assert_equal Verdict.results.keys.sort, Verdict::GLYPHS.keys.sort
  end
end
