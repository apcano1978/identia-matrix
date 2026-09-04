# frozen_string_literal: true

require "test_helper"

class AgentConfigTest < ActiveSupport::TestCase
  include DomainBuilders

  # ── El bloqueo por cliente (F2 §1.5, aplicado en P2) ─────────────────────

  # F2 avisaba de que estas claves son LITERALES y de que, escritas de dos
  # formas distintas, el bloqueo no se aplica y nadie se entera. Este test es la
  # guarda, y ya cazó una: la tercera de la lista original, `link.independence`,
  # NO EXISTÍA en ninguna configuración. Habría dado la sensación de proteger
  # algo sin proteger nada.
  test "cada clave bloqueada existe de verdad en la configuracion global" do
    DesignSeed.call

    huerfanas = AgentConfig::LOCKED_KEYS.flat_map do |agent, paths|
      settings = AgentConfig.effective_for(agent: agent)
      paths.reject { |path| settings.dig(*path.split(".")).present? }
           .map { |path| "#{agent}.#{path}" }
    end

    assert_empty huerfanas,
                 "hay claves bloqueadas que no existen: el bloqueo no protege nada"
  end

  test "un override de cliente pierde las claves bloqueadas" do
    settings = { "morfeo_loop" => { "max_returns" => 9 },
                 "model" => { "spec_length" => "verbose" } }

    result = AgentConfig.without_locked(settings, agent: "neo")

    assert_nil result["morfeo_loop"]
    assert_equal "verbose", result.dig("model", "spec_length")
  end

  test "podar no deja contenedores vacios colgando" do
    # `"morfeo_loop" => {}` no cambia nada al fusionar, pero le dice a quien lo
    # lea que ahí hay un ajuste, y no lo hay.
    result = AgentConfig.without_locked({ "morfeo_loop" => { "max_returns" => 9 } },
                                        agent: "neo")

    assert_equal({}, result)
  end

  test "podar no toca lo que el agente no tiene bloqueado" do
    settings = { "morfeo_loop" => { "max_returns" => 9 } }

    # `morfeo_loop.max_returns` está bloqueada para NEO, no para TANK.
    assert_equal settings, AgentConfig.without_locked(settings, agent: "tank")
  end

  test "podar no modifica el hash que recibe" do
    settings = { "morfeo_loop" => { "max_returns" => 9 } }
    AgentConfig.without_locked(settings, agent: "neo")

    assert_equal({ "morfeo_loop" => { "max_returns" => 9 } }, settings)
  end

  # ── La procedencia de la configuración ───────────────────────────────────

  test "cada ejecucion guarda la configuracion con la que corrio" do
    # La vigente contesta «cómo se trabaja hoy»; esta, «cómo se hizo esto». Sin
    # ella, cambiar un umbral dejaría inexplicable un artefacto ya publicado, y
    # un artefacto no se puede anotar después.
    client = build_client
    AgentConfig.create!(agent: :tank, settings: { "contexto" => { "profundidad" => "amplia" } })
    initiative = place(build_initiative(client: client), :tank)
    %w[booking-core owner-web pricing-svc].each do |name|
      InitiativeRepository.create!(initiative: initiative,
                                   repository: build_repository(client: client, name: name),
                                   pinned_sha: "4f2a9c1")
    end

    run = Agents::Run.call(initiative: initiative, agent: :tank,
                           purpose: :context).agent_run

    assert_equal({ "contexto" => { "profundidad" => "amplia" } }, run.config)
  end

  test "cambiar la configuracion despues no reescribe lo que ya corrio" do
    client = build_client
    config = AgentConfig.create!(agent: :tank, settings: { "contexto" => { "profundidad" => "amplia" } })
    initiative = place(build_initiative(client: client), :tank)
    %w[booking-core owner-web pricing-svc].each do |name|
      InitiativeRepository.create!(initiative: initiative,
                                   repository: build_repository(client: client, name: name),
                                   pinned_sha: "4f2a9c1")
    end

    run = Agents::Run.call(initiative: initiative, agent: :tank,
                           purpose: :context).agent_run
    config.update!(settings: { "contexto" => { "profundidad" => "minima" } })

    assert_equal "amplia", run.reload.config.dig("contexto", "profundidad")
  end
end
