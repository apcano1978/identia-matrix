require "application_system_test_case"

# P1 · el alta, desde la pantalla. Aquí se comprueba lo que un test de
# integración no ve: que los formularios existen, que están donde tienen que
# estar y que dicen lo que hace falta decir.
class AltaTest < ApplicationSystemTestCase
  setup do
    DesignSeed.call
    sign_in_as Platform::User.find_by!(platform_id: 1)
    visit client_path("vivla")
  end

  test "la ficha ya no dice que sea de solo lectura entera" do
    # Sigue siendo cierto del CLIENTE —eso es proyección de platform y matrix no
    # modifica un origen— y deja de serlo de lo que es suyo.
    assert_text "el cliente y sus proyectos se gestionan en identia-platform"
    assert_text "los evolutivos y los repositorios son de matrix"
  end

  test "abrir un evolutivo desde la ficha del cliente" do
    find("summary", text: "abrir un evolutivo").click
    fill_in "title", with: "Unificar el calendario"
    check "repo-#{Repository.find_by!(name: 'booking-core').id}"
    click_on "abrir ⏎"

    assert_text "Unificar el calendario"
    assert_text "necesidad", count: 3   # la etiqueta de etapa, no la inglesa del enum
  end

  test "el formulario avisa de que nadie lo va a mover todavía" do
    # Si no lo dijera, quien lo abra se quedaría buscando un botón de avanzar
    # que no existe hasta F9.
    find("summary", text: "abrir un evolutivo").click

    assert_text "el pipeline lo mueven los agentes, y todavía no están conectados"
  end

  test "registrar un repositorio, con su CI opcional" do
    find("summary", text: "registrar un repositorio").click
    fill_in "name", with: "rates-engine"
    fill_in "ci_provider", with: "github"
    fill_in "ci_repo_slug", with: "vivla/rates-engine"
    click_on "registrar ⏎"

    assert_text "rates-engine"
    assert Repository.find_by!(name: "rates-engine").ci_configured?
  end

  test "un cliente sin repositorios explica por qué no puede abrir un evolutivo" do
    visit client_path("navantia")
    Repository.where(platform_client: Platform::Client.find_by!(slug: "navantia")).destroy_all
    visit client_path("navantia")

    assert_text "Para abrir un evolutivo hace falta al menos un repositorio"
    assert_no_selector "summary", text: "abrir un evolutivo"
  end
end
