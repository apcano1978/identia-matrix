require "application_system_test_case"

# El proyecto es la raíz desde F11: la matriz evolutivo × repositorio, los
# repositorios y las dos altas viven aquí, no en la ficha del cliente. Lo que
# sigue siendo del cliente está en `clients_test`.
class ProjectsTest < ApplicationSystemTestCase
  setup do
    DesignSeed.call
    sign_in_as Platform::User.find_by!(platform_id: 1)
    click_on "PROYECTOS"
    # La barrera del setup. Sin ella el primer clic de cada test puede caer sobre
    # el panel todavía, y el fallo sale en un test distinto cada vez según el
    # orden — que es lo que hace difícil de leer esta familia de fallos.
    assert_text "DE CLIENTE · 6"
  end

  # ── Las dos pestañas (B7b) ────────────────────────────────────────────────

  # Los dos contadores van siempre, se pinte la lista que se pinte: una pestaña
  # que no dice cuántos hay detrás no invita a pulsarla.
  test "las dos pestañas cuentan las dos, y arranca en la de cliente" do
    assert_text "DE CLIENTE · 6"
    assert_text "PROPIOS · 0"
    assert_selector ".bg-terminal-fg", text: "DE CLIENTE"
    assert_text "VIVLA"
  end

  test "y la de propios enseña lo que falta en vez de quedarse en blanco" do
    click_on "PROPIOS · 0"

    assert_current_path projects_path(tab: "propios")
    assert_text "Matrix todavía no trabaja sobre nada suyo"
    assert_no_text "VIVLA"
  end

  test "un proyecto propio aparece en su pestaña y no en la otra" do
    Projects::Open.call(slug: "matrix-interna", name: "Matrix interna",
                        actor: "test")

    visit projects_path(tab: "propios")
    assert_text "PROPIOS · 1"
    assert_text "Matrix interna"
    assert_text "PROPIO"

    visit projects_path
    assert_no_text "Matrix interna"
  end

  # Un `tab` que no existe no revienta ni enseña la lista entera: cae en el
  # defecto, que es el que la maqueta pinta.
  test "una pestaña inventada cae en la de cliente" do
    visit projects_path(tab: "inventada")

    assert_selector ".bg-terminal-fg", text: "DE CLIENTE"
    assert_text "VIVLA"
  end

  test "las tarjetas se pintan con sus evolutivos y repositorios" do
    within(card_for("VIVLA")) do
      assert_text "5 evolutivos"
      assert_text "3 repositorios"
    end
    assert_text "↳ el evolutivo es el eje de trabajo; el repositorio, el eje de memoria"
  end

  test "el chip de la tarjeta es el corto, no el largo de la matriz" do
    within(card_for("MANGO")) { assert_text "⊘ escalado" }
    within(card_for("MANGO")) { assert_no_text "inconclusive" }
  end

  # LA COMPROBACIÓN DE LA FASE: la matriz de vivla, celda a celda.
  test "la matriz de vivla da cinco evolutivos y tres repositorios" do
    open_vivla

    assert_text "## EVOLUTIVOS"
    assert_text "eje de trabajo · recorren el pipeline de 12 etapas"
    assert_text "## REPOSITORIOS"
    assert_equal 5, all("a[href*='/initiatives/']").size
    assert_equal %w[booking-core owner-web pricing-svc], matrix_columns
  end

  test "y cada celda tiene el color que le toca" do
    open_vivla

    # ev-031 toca los tres y sigue vivo: tres puntos en oro.
    assert_equal %w[oro oro oro], cells_for("precio-festivos")
    # ev-014 toca solo booking-core.
    assert_equal %w[oro vacío vacío], cells_for("motor-disponibilidad")
    # ev-009 tocó dos y ya cerró: verde, no oro.
    assert_equal %w[verde verde vacío], cells_for("alta-socio")
  end

  test "el pie cuenta los multi-repo sobre todos, no sobre la pagina" do
    open_vivla

    assert_text "2 de 5 evolutivos tocan más de un repositorio"
  end

  # La ficha del proyecto tiene dos formularios —el alta de evolutivo y la de
  # repositorio— y lo que afirma es la distinción que importa: **el cliente y
  # sus proyectos siguen siendo de platform** y matrix no los toca; los
  # evolutivos y los repositorios son suyos.
  test "la ficha distingue lo que es de platform de lo que es de matrix" do
    open_vivla

    assert_text "el cliente y sus proyectos se gestionan en identia-platform"
    assert_text "los evolutivos y los repositorios son de matrix"
  end

  test "y no ofrece editar la proyeccion por ningun sitio" do
    open_vivla

    # Los dos formularios de la pantalla son altas de lo que es de matrix.
    # Ninguno apunta a la proyección, que es de solo lectura.
    acciones = all("main form", visible: :all).map { |f| f[:action] }

    assert_equal 2, acciones.size
    assert acciones.all? { |a| a.end_with?("/initiatives", "/repositories") },
           "hay un formulario que no es un alta de matrix: #{acciones.inspect}"
  end

  test "el panel explica el modelo y lista los overrides" do
    open_vivla

    assert_text "son dos ejes que se cruzan, no una jerarquía"
    assert_text "antonio"
    assert_text "neo.model.spec_length"
    assert_text "verbose"
  end

  test "de la matriz se entra al evolutivo y del repositorio a su ficha" do
    open_vivla
    click_on "Motor de disponibilidad"
    assert_current_path project_initiative_path("vivla", "motor-disponibilidad")

    page.go_back
    click_on "booking-core"
    assert_current_path project_repository_path("vivla", "booking-core")
  end

  # De quién es el proyecto se dice en la ficha, y el nombre del cliente lleva a
  # la suya: es el único sitio por el que se cruza de un eje al otro.
  test "el proyecto de cliente nombra al suyo y lleva a su ficha" do
    open_vivla

    click_on "VIVLA", match: :first
    assert_current_path client_path("vivla")
  end

  private
    def open_vivla
      click_on "VIVLA"
      assert_selector "h1", text: "VIVLA"
    end

    def card_for(name) = find("a", text: name, match: :prefer_exact)

    def matrix_columns = all("[data-matrix-column]").map(&:text)

    # Por NOMBRE: es lo que lleva la URL desde F11.
    def cells_for(slug)
      find("a[href$='/#{slug}']").all("span.text-center span").map do |cell|
        next "vacío" if cell.text == "·"

        cell[:class].include?("text-glyph-done") ? "verde" : "oro"
      end
    end
end
