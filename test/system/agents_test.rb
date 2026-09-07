require "application_system_test_case"

class AgentsTest < ApplicationSystemTestCase
  setup do
    DesignSeed.call
    sign_in_as Platform::User.find_by!(platform_id: 1)
    click_on "AGENTES"
    # La barrera del setup. Sin ella el primer `click_on` de cada test puede caer
    # sobre el panel todavía, y entonces el fallo aparece en un test distinto
    # cada vez según el orden — que es lo que lo hace difícil de leer.
    #
    # La pantalla abre por el primero del PIPELINE, y desde B8 ese es el
    # ARQUITECTO, no TANK. El resto de tests hablan de la configuración de TANK,
    # así que se va a la suya explícitamente en vez de depender del defecto.
    assert_selector "h1", text: "ARQUITECTO"
    click_on "tank"
    assert_selector "h1", text: "TANK"
  end

  test "los siete agentes tienen pestaña" do
    within("div", text: "agents:", match: :first) do
      %w[arquitecto tank neo morfeo trinity seraph link].each { |a| assert_text a }
    end
  end

  # El orden de la barra es el del TRABAJO, no el del enum: el ARQUITECTO es el
  # último de `AgentRun.agents` y el primero en actuar.
  test "y salen en el orden en que trabajan" do
    within("div", text: "agents:", match: :first) do
      claves = all("a, span").map(&:text).select { |t| AgentRun.agents.key?(t) }

      assert_equal %w[arquitecto tank neo seraph morfeo trinity link],
                   claves.uniq
    end
  end

  # F3 la dejó en solo lectura y F9 la abre (P2): hasta que hubo agentes de
  # verdad, un formulario que guarda algo que nadie lee era peor que no tenerlo.
  test "la configuracion global se puede editar" do
    fill_in "settings", with: '{"contexto":{"profundidad":"solo el repositorio"}}'
    click_on "guardar"

    assert_text "Configuración de TANK global guardada"
    assert_equal({ "contexto" => { "profundidad" => "solo el repositorio" } },
                 AgentConfig.global.find_by(agent: "tank").settings)
  end

  test "un JSON roto no guarda nada y lo dice" do
    antes = AgentConfig.global.find_by(agent: "tank").settings

    fill_in "settings", with: "{esto no es json"
    click_on "guardar"

    assert_text "no es un JSON válido"
    assert_equal antes, AgentConfig.global.find_by(agent: "tank").settings
  end

  test "queda constancia de quien lo cambio" do
    fill_in "settings", with: '{"contexto":{"indexa_adr":false}}'
    click_on "guardar"
    assert_text "guardada"

    assert_equal Platform::User.find_by!(platform_id: 1),
                 AgentConfig.global.find_by(agent: "tank").updated_by_user
  end

  test "un cliente no puede sobrescribir un ajuste bloqueado" do
    # `morfeo_loop.max_returns` sostiene un invariante: un cliente que se diera
    # dos vueltas más estaría comprando otra política, no ajustando la suya.
    open_agent "neo"
    open_client "vivla"

    assert_text "No admiten override"
    fill_in "settings", with: '{"morfeo_loop":{"max_returns":9},"model":{"spec_length":"verbose"}}'
    click_on "guardar"
    assert_text "guardada"

    override = AgentConfig.find_by(agent: "neo",
                                   project: Project.find_by!(slug: "vivla"))

    assert_nil override.settings["morfeo_loop"],
               "la clave bloqueada se poda; el resto del cambio se guarda"
    assert_equal "verbose", override.settings.dig("model", "spec_length")
  end

  test "el mismo ajuste SI se puede cambiar en la global" do
    # Bloquearlo también arriba dejaría al sistema sin forma de cambiarlo nunca.
    open_agent "neo"

    fill_in "settings", with: '{"morfeo_loop":{"max_returns":3}}'
    click_on "guardar"
    assert_text "guardada"

    assert_equal 3, AgentConfig.global.find_by(agent: "neo")
                               .settings.dig("morfeo_loop", "max_returns")
  end

  test "las secciones van en orden de trabajo, no en el de postgres" do
    open_agent "seraph"

    assert_equal %w[dod_pass qa_cycle verificacion dictamen],
                 all("[data-section]").map { |node| node[:"data-section"] }
  end

  test "el aviso de morfeo_loop va literal" do
    open_agent "neo"

    assert_text "Superado el límite, el ciclo escala a revisión humana en vez de " \
                "reintentar. No sobrescribible por cliente."
  end

  test "el de qa_cycle tambien" do
    open_agent "seraph"

    assert_text "Agotados los ciclos el flujo se detiene. Solo un humano lo " \
                "reinicia con una nota, que entra como ◆ ORIGEN. La escalada " \
                "queda en el historial."
  end

  test "y el de la independencia de LINK" do
    open_agent "link"

    assert_text "LINK no comparte contexto de redacción con NEO. Quien escribió " \
                "el plan es el peor narrador del desvío frente al plan. No configurable."
  end

  # Uno de los siete restos de la maqueta que no se copian: ofrecer el
  # interruptor sugeriría que la inmutabilidad se puede apagar.
  test "no hay «permitir reemplazar una version publicada»" do
    open_agent "link"

    assert_no_text "permitir reemplazar"
  end

  test "el scope enseña el diff entre la global y el override del cliente" do
    open_agent "neo"
    assert_text "Elige un cliente arriba para ver qué le cambia"

    open_client "vivla"

    assert_text "model.spec_length"
    assert_text "verbose"
  end

  test "un cliente sin override lo dice" do
    open_agent "neo"
    open_client "caser"

    assert_text "caser hereda la global sin cambios"
  end

  test "la configuracion efectiva aplica el override" do
    open_agent "neo"
    open_client "vivla"

    within("[data-section='model']") { assert_text "verbose" }
  end

  private
    # `click_on` no espera a la navegación; `assert_selector` sí. Sin esto el
    # test lee la pantalla del agente anterior.
    def open_agent(key)
      click_on key
      assert_selector "h1", text: key.upcase
    end

    # Y lo mismo para el cliente, por una razón MÁS SUTIL que la de arriba: la
    # sección `model` existe en las dos pantallas, así que un `within` sobre ella
    # la encuentra en la vieja sin esperar y afirma contra la configuración
    # global. El panel es lo único que nombra al cliente, y por eso es lo que
    # sirve de barrera. Sin esto el test falla según el orden de ejecución.
    def open_client(slug)
      click_on slug
      assert_text "global vs #{slug}"
    end
end
