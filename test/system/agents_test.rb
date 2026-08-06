require "application_system_test_case"

class AgentsTest < ApplicationSystemTestCase
  setup do
    DesignSeed.call
    sign_in_as Platform::User.find_by!(platform_id: 1)
    click_on "AGENTES"
  end

  test "los seis agentes tienen pestaña" do
    within("div", text: "agents:", match: :first) do
      %w[tank neo morfeo trinity seraph link].each { |a| assert_text a }
    end
  end

  # F3 enseña; F9 edita. Un formulario que guarda algo que nadie lee todavía es
  # peor que no tenerlo.
  test "la pantalla es de solo lectura: ni un campo" do
    assert_text "configuración en solo lectura · se edita en F9"
    assert_no_selector "main input"
    assert_no_selector "main select"
    assert_no_selector "main button[type=submit]"
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

    click_on "vivla"

    assert_text "model.spec_length"
    assert_text "verbose"
  end

  test "un cliente sin override lo dice" do
    open_agent "neo"
    click_on "caser"

    assert_text "caser hereda la global sin cambios"
  end

  test "la configuracion efectiva aplica el override" do
    open_agent "neo"
    click_on "vivla"

    within("[data-section='model']") { assert_text "verbose" }
  end

  private
    # `click_on` no espera a la navegación; `assert_selector` sí. Sin esto el
    # test lee la pantalla del agente anterior.
    def open_agent(key)
      click_on key
      assert_selector "h1", text: key.upcase
    end
end
