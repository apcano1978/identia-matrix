require "application_system_test_case"

# La pantalla de fuentes es la respuesta visible a «¿qué puede leer un agente?»,
# y por tanto donde la frontera de cliente se hace inspeccionable.
class SourcesTest < ApplicationSystemTestCase
  setup do
    DesignSeed.call
    sign_in_as Platform::User.find_by!(platform_id: 1)
    visit project_initiative_sources_path("vivla", "precio-festivos")
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

  # Los contadores por su TÍTULO, no por su posición: la pantalla ganó una
  # sección en F12 y un `last(2)` habría empezado a contar otra cosa sin que
  # nada se pusiera rojo.
  test "nueve fuentes en ámbito y nueve heredadas del cliente" do
    assert_equal "(9)", count_of("EN EL ÁMBITO DE ESTE EVOLUTIVO")
    assert_equal "(9)", count_of("HEREDADAS DE VIVLA")
  end

  # F12 · la sección de lo SUBIDO. En vivla está vacía —el seed no sube nada— y
  # se pinta igual: decir que está vacía es decir dónde se empieza.
  test "y la sección del proyecto, vacía, dice de dónde saldría" do
    assert_equal "(0)", count_of("DEL PROYECTO")
    assert_text "subidos a vivla · se citan igual, sin pasar por platform"
    assert find("[data-card='docs-proyecto']").has_text?("Ninguna.")
  end

  # No hay tarjeta de reuniones propias: matrix no acepta transcripciones, y una
  # tarjeta vacía insinuaría que algún día se llenará por aquí.
  test "pero no ofrece subir reuniones, que no se suben a matrix" do
    assert_no_selector "[data-card='reuniones-proyecto']"
    assert_text "Las transcripciones no se suben a matrix"
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
    visit project_initiative_path("vivla", "precio-festivos")
    click_on "sources"

    assert_text "Fuentes en ámbito"
    assert_text "projects/vivla/precio-festivos/sources"

    click_on "← precio-festivos"

    assert_text "PIPELINE"
  end

  # Las fuentes son del evolutivo, y el evolutivo cuelga del proyecto: el rail
  # se queda donde está el trabajo.
  test "y el rail sigue en PROYECTOS" do
    assert_selector ".rail-entry-on", text: "PROYECTOS"
  end

  test "es una pantalla de lectura: no se edita nada desde aquí" do
    assert_no_selector "main form"
    assert_no_selector "main input, main select, main textarea"
  end

  private
    # El contador de una sección, por su título. El primer `span` hermano: el
    # otro es la glosa, que va después de la regla.
    def count_of(title)
      find(".section-title", text: "## #{title}")
        .find(:xpath, "following-sibling::span[1]").text
    end
end
