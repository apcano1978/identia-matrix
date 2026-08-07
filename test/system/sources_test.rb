require "application_system_test_case"

# La pantalla de fuentes es la respuesta visible a «¿qué puede leer un agente?»,
# y por tanto donde la frontera de cliente se hace inspeccionable.
class SourcesTest < ApplicationSystemTestCase
  setup do
    DesignSeed.call
    sign_in_as Platform::User.find_by!(platform_id: 1)
    visit client_initiative_sources_path("vivla", "ev-031")
  end

  test "dice de quién es el ámbito y que no se escribe en él" do
    assert_text "Fuentes en ámbito"
    assert_text "lo que TANK puede leer y citar para ev-031"
    assert_text "write access: none"
  end

  # El commit FIJADO, no la cabeza del repositorio: un evolutivo trabaja contra
  # un punto concreto de la historia.
  test "los tres repositorios con su commit fijado y su indexado" do
    assert_text "CÓDIGO · 3 REPOSITORIOS"

    # El separador de miles es el punto: en español «3,412» es tres coma cuatro
    # uno dos, que es otro número.
    { "booking-core" => %w[4f2a9c1 3.412],
      "owner-web" => %w[e91b330 1.880],
      "pricing-svc" => %w[b7c0d21 640] }.each do |name, (sha, files)|
      row = find(".grid-source-repos", text: name)

      assert row.has_text?(sha), "#{name} tiene que enseñar su commit fijado"
      assert row.has_text?("#{files} fich."), "#{name} tiene que enseñar su indexado"
    end
  end

  # La columna es didáctica a propósito: enseña la forma exacta que hay que
  # escribir para citar ese repositorio.
  test "y el prefijo de cita de cada uno" do
    assert_text "[src:code/booking-core:…]"
    assert_text "[src:code/owner-web:…]"
    assert_text "[src:code/pricing-svc:…]"
  end

  test "nueve fuentes en ámbito y nueve heredadas del cliente" do
    assert_text "EN EL ÁMBITO DE ESTE EVOLUTIVO"
    assert_text "HEREDADAS DE VIVLA"

    assert_equal %w[(9) (9)],
                 all(".section-title + span").map(&:text).last(2)
  end

  # El concepto entero de la pantalla: el ámbito es un filtro, no posesión.
  test "acta-precios está en ámbito y se marca como compartida con ev-014" do
    assert_text "acta-precios 7 refs · también en ev-014"
  end

  test "lo heredado no finge tener referencias de este evolutivo" do
    heredadas = find("[data-card='docs-cliente']")

    assert heredadas.has_text?("glosario-negocio")
    assert heredadas.has_no_text?("refs")
    assert heredadas.has_no_text?("sync")
  end

  test "las reuniones heredadas llevan su fecha" do
    assert_text "comite-de-direccion"
    assert_text "revision-trimestral"
    assert_text "onboarding-marca"
  end

  # La maqueta enumeraba DOS excepciones porque en su diseño SERAPH levantaba
  # clones que ejecutaban. Al decidirse en F10 que SERAPH lee el CI del
  # repositorio, esa excepción desapareció.
  test "la caja de cierre enumera una sola excepción, no dos" do
    assert_text "Matrix nunca modifica un origen, y no ejecuta código ajeno."
    assert_text "Una sola excepción, acotada:"
    assert_text "artifacts://"
    assert_no_text "clones efímeros"
  end

  test "se llega desde el evolutivo y se vuelve" do
    visit client_initiative_path("vivla", "ev-031")
    click_on "sources"

    assert_text "Fuentes en ámbito"
    assert_text "clients/vivla/ev-031/sources"

    click_on "← ev-031"

    assert_text "PIPELINE"
  end

  test "y el rail sigue en CLIENTES" do
    assert_selector ".rail-entry-on", text: "CLIENTES"
  end

  test "es una pantalla de lectura: no se edita nada desde aquí" do
    assert_no_selector "main form"
    assert_no_selector "main input, main select, main textarea"
  end
end
