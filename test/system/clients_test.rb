require "application_system_test_case"

# Lo que sigue siendo del CLIENTE cuando la raíz pasa a ser el proyecto: su
# identidad, su admisión, sus fuentes y la lista de sus proyectos. La matriz, los
# repositorios y las dos altas se mudaron a `projects_test`.
class ClientsTest < ApplicationSystemTestCase
  setup do
    DesignSeed.call
    sign_in_as Platform::User.find_by!(platform_id: 1)
    click_on "CLIENTES"
    # La barrera del setup. Sin ella el primer clic de cada test puede caer sobre
    # el panel todavía, y el fallo sale en un test distinto cada vez según el
    # orden — que es lo que hace difícil de leer esta familia de fallos.
    assert_text "6 clientes"
  end

  test "las seis tarjetas se pintan con sus evolutivos y repositorios" do
    assert_text "6 clientes"
    assert_text "VIVLA"
    within(card_for("VIVLA")) do
      assert_text "5 evolutivos"
      assert_text "3 repositorios"
    end
  end

  test "el chip de la tarjeta es el corto, no el largo de la matriz" do
    within(card_for("MANGO")) { assert_text "⊘ escalado" }
    within(card_for("MANGO")) { assert_no_text "inconclusive" }
  end

  # La ficha del cliente conserva lo que no es de ningún proyecto, y lista los
  # que tiene. La matriz ya no está aquí: entrar al trabajo es entrar por el
  # proyecto.
  test "la ficha lista sus proyectos y ya no trae la matriz" do
    open_vivla

    assert_text "## PROYECTOS"
    assert_text "de aquí cuelgan los evolutivos y los repositorios"
    assert_no_text "## EVOLUTIVOS"
    assert_no_selector "[data-matrix-column]"
  end

  test "y desde ahi se entra al proyecto, que es la puerta al trabajo" do
    open_vivla

    click_on "Unificar precios y calendario"
    assert_current_path project_path("vivla")
  end

  test "la ficha distingue lo que es de platform de lo que es de matrix" do
    open_vivla

    assert_text "el cliente y sus proyectos se gestionan en identia-platform"
    assert_text "los evolutivos y los repositorios son de matrix"
  end

  # Ninguna escritura del cliente: la proyección es de solo lectura, y desde
  # F11 tampoco cuelgan de aquí las dos altas de matrix.
  test "y no ofrece editar el cliente por ningun sitio" do
    open_vivla

    assert_empty all("main form", visible: :all).map { |f| f[:action] }
  end

  # Cero PII: de la persona de contacto viaja el cargo, nunca el nombre.
  test "del contacto solo se enseña el cargo" do
    open_vivla

    assert_text "contacto · cto"
    assert_no_text "marta"
  end

  test "el cliente admitido antes de tener proyecto se pinta EN PREPARACIÓN" do
    # La tarjeta de un cliente sin evolutivos se queda muda, y en preparación
    # eso no es un hueco: es el estado correcto y hay que decirlo.
    cliente = Platform::Record.writing do
      Platform::Client.create!(platform_id: 8_101, slug: "en-preparacion",
                               name: "Acme Preparada", sector: "industrial")
    end
    ClientAdmission.create!(platform_id: cliente.platform_id,
                            reason: "reuniendo documentación", admitted_by: "antonio")

    visit clients_path

    within(card_for("Acme Preparada")) do
      assert_text "EN PREPARACIÓN"
      assert_text "Admitido antes de tener proyecto"
    end

    # Y en su ficha, que dice el estado y no finge tener proyectos.
    visit client_path(cliente)
    assert_selector "h1", text: "Acme Preparada"
    assert_text "EN PREPARACIÓN"
    assert_text "## PROYECTOS"
    assert_no_selector "a[href^='/projects/']"
  end

  test "un cliente con trabajo no lleva la marca de preparación" do
    within(card_for("VIVLA")) { assert_no_text "EN PREPARACIÓN" }
  end

  private
    def open_vivla
      click_on "VIVLA"
      assert_selector "h1", text: "VIVLA"
    end

    def card_for(name) = find("a", text: name, match: :prefer_exact)
end
