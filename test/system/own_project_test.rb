require "application_system_test_case"

# EL TEST DEL BLOQUE B7b: matrix trabajando sobre algo suyo, de punta a punta.
#
# Hasta F11 todo lo que existía en matrix venía de un cliente de
# identia-platform. Este test recorre el ciclo entero de un proyecto que no viene
# de ninguno —crearlo, registrarle un repositorio, abrirle un evolutivo, entrar
# en su ficha, mirarlo en el dashboard— y es el que habría cazado los siete
# sitios que resolvían la ruta o el rótulo a través del cliente del evolutivo.
#
# Todos funcionaban de casualidad: el slug del proyecto se heredó del cliente al
# mudarse la raíz en B3, así que pasarle el cliente producía la URL correcta. Con
# `platform_client` a `nil` daban `UrlGenerationError` o `NoMethodError`, y no
# había un solo test que pasara por ahí porque no había forma de crear un
# proyecto sin cliente.
#
# Los dos últimos se INVIRTIERON en B9½: B7b los dejó escritos afirmando lo que
# todavía no se podía —ejecutar un agente sobre un proyecto propio— con el
# bloque que lo levantaría nombrado dentro.
class OwnProjectTest < ApplicationSystemTestCase
  setup do
    DesignSeed.call
    sign_in_as Platform::User.find_by!(platform_id: 1)
  end

  # ── El alta ────────────────────────────────────────────────────────────────

  test "se abre un proyecto propio y se aterriza en su ficha" do
    visit new_project_path

    assert_text "un proyecto es una frontera: nada se lee de fuera"
    fill_in "slug", with: "matrix-interna"
    fill_in "name", with: "Matrix interna"
    click_on "ABRIR EL PROYECTO ⏎"

    assert_current_path project_path("matrix-interna")
    assert_selector "h1", text: "Matrix interna"
    assert_text "PROPIO"
    assert_text "proyecto propio · nada que sincronizar"
    assert Project.find_by!(slug: "matrix-interna").own?
  end

  # La pantalla enseña la opción de cliente APAGADA, y eso es lo que enseña de
  # verdad: que ese proyecto no se crea a mano porque llega sincronizado.
  test "y la opción de cliente se ve, pero no se puede elegir" do
    visit new_project_path

    assert_text "Cliente de identia-platform"
    assert_text "nacen con su cliente y se van con él"
    assert_no_selector "input[type=radio]"
    assert_no_selector "select"
  end

  test "el nombre corto mal escrito se rechaza diciendo por qué" do
    visit new_project_path
    fill_in "slug", with: "Matrix Interna"
    fill_in "name", with: "Matrix interna"
    click_on "ABRIR EL PROYECTO ⏎"

    assert_text "claves de artefacto"
    assert_nil Project.find_by(name: "Matrix interna")
  end

  test "y uno que ya usa un cliente tampoco vale" do
    visit new_project_path
    fill_in "slug", with: "vivla"
    fill_in "name", with: "Vivla interna"
    click_on "ABRIR EL PROYECTO ⏎"

    assert_text "ya hay un proyecto que se llama"
  end

  # ── El ciclo entero sobre él ───────────────────────────────────────────────

  # Es el recorrido que rompía. Cada `assert` de aquí abajo era una excepción
  # antes de B7b, y ninguna suite pasaba por ellas.
  test "se le registra un repositorio, se le abre un evolutivo y todo sigue en pie" do
    open_matrix_interna

    assert_text "Para abrir un evolutivo hace falta al menos un repositorio"

    find("summary", text: "registrar un repositorio").click
    fill_in "name", with: "identia-matrix"
    click_on "registrar ⏎"

    assert_current_path project_repository_path("matrix-interna", "identia-matrix")
    assert_text "registro · nada que atender"

    visit project_path("matrix-interna")
    find("summary", text: "abrir un evolutivo").click
    fill_in "title", with: "Rediseño de la interfaz"
    check "repo-#{Repository.find_by!(name: 'identia-matrix').id}"
    click_on "abrir ⏎"

    assert_text "Rediseño de la interfaz"
    assert_text "PIPELINE"
  end

  # `initiatives_helper#artifact_tabs` y el panel del evolutivo. Los dos leían el
  # cliente: el primero para construir las rutas de las tres pestañas de
  # evidencia, el segundo para pintar la fila «cliente».
  test "la ficha del evolutivo se pinta, y su panel dice el proyecto en vez del cliente" do
    initiative = own_initiative

    visit project_initiative_path("matrix-interna", initiative.slug)

    assert_text "PIPELINE"
    panel = find("[data-pane='meta']")

    assert panel.has_text?("proyecto"), "el panel nombra la raíz"
    assert panel.has_text?("Matrix interna")
    assert panel.has_no_text?("cliente"), "no hay ninguno, y la fila no se pinta vacía"
  end

  # `dashboard_helper#tray_destination` y `Dashboard::Board#sources_for`. El
  # primero construye el enlace de cada bandeja; el segundo el `proyecto/repo
  # @sha` de cada fila.
  test "el dashboard lo lista sin caerse, y su repositorio lleva el slug del proyecto" do
    initiative = own_initiative
    place_at_gate_1(initiative)

    visit root_path

    assert_text "Rediseño de la interfaz"
    assert_text "matrix-interna/identia-matrix"
    assert_selector "a[href='#{project_initiative_gate_1_path('matrix-interna', initiative.slug)}']"
  end

  # Un proyecto propio no hereda documentación de ningún cliente, y eso NO es un
  # hueco: es la frontera funcionando. La consulta sale con `platform_client_id`
  # nulo y devuelve vacío, que es lo correcto.
  test "sus fuentes están vacías y la pantalla no finge heredar de nadie" do
    initiative = own_initiative

    visit project_initiative_sources_path("matrix-interna", initiative.slug)

    assert_text "Fuentes en ámbito"
    assert_text "identia-matrix"
    assert_no_text "HEREDADAS DE"
    assert_no_text "acta-precios"
  end

  # El formulario de evolutivo no enseña un desplegable vacío: dice por qué no
  # hay ninguno al otro lado.
  test "el alta de evolutivo no ofrece vincular con platform, y lo explica" do
    open_matrix_interna
    build_repository_through_screen

    visit project_path("matrix-interna")
    find("summary", text: "abrir un evolutivo").click

    assert_text "este es un proyecto propio y no hay nada al otro lado"
    assert_no_selector "select#platform_project_id"
  end

  # ── Y desde B9½, también se le puede poner a trabajar un agente ───────────
  #
  # Estos dos tests decían lo contrario hasta B9½, y ese es exactamente su valor:
  # B7b los escribió afirmando lo que TODAVÍA no se podía, con el bloque que lo
  # levantaría escrito dentro. Se invierten, no se borran.

  # `Runtime::Request` valida el payload contra `agent_run.v1.json` antes de
  # enviarlo y con los dos runtimes, fake incluido. Ese contrato exigía `client`,
  # así que un agente sobre un proyecto propio fallaba DENTRO de matrix. Ahora la
  # frontera que viaja obligatoria es el PROYECTO, y el cliente se omite cuando
  # no lo hay.
  test "el payload se construye, con el proyecto y sin cliente" do
    initiative = own_initiative
    run = AgentRun.create!(initiative: initiative, agent: :tank, purpose: :context,
                           iteration: initiative.iteration,
                           code: "tank/#{initiative.slug}-context-1",
                           status: :running, started_at: Time.current)

    config = Runtime::Request.for(run).payload["config"]

    assert_equal({ "slug" => "matrix-interna", "name" => "Matrix interna" },
                 config["project"])
    assert_not config.key?("client"),
               "la clave se OMITE, no se manda a null: el contrato espera un objeto"
  end

  test "y la ficha ofrece el botón, que es lo que B7b no podía" do
    initiative = own_initiative
    place(initiative, :tank)

    visit project_initiative_path("matrix-interna", initiative.slug)

    assert_button "▶ poner a trabajar a TANK"
    assert_no_text "Los agentes todavía no trabajan sobre proyectos propios"
  end

  private
    def open_matrix_interna
      Projects::Open.call(slug: "matrix-interna", name: "Matrix interna",
                          actor: "test")
      visit project_path("matrix-interna")
      assert_selector "h1", text: "Matrix interna"
    end

    def build_repository_through_screen
      find("summary", text: "registrar un repositorio").click
      fill_in "name", with: "identia-matrix"
      click_on "registrar ⏎"
      assert_text "registro · nada que atender"
    end

    # El evolutivo ya abierto, por el camino de dominio: los tests de arriba ya
    # prueban que la pantalla lo abre, y repetirlo aquí solo alarga la suite.
    def own_initiative
      project = Projects::Open.call(slug: "matrix-interna", name: "Matrix interna",
                                    actor: "test")
      repository = Repository.create!(project: project, name: "identia-matrix",
                                      default_branch: "main")

      Initiatives::Open.call(project: project, title: "Rediseño de la interfaz",
                             repositories: [ repository ], actor: "test")
    end

    # A una etapa que aparece en una bandeja del dashboard con su enlace.
    def place_at_gate_1(initiative)
      initiative.stage_entries.update_all(status: StageEntry.statuses[:done],
                                          exited_at: Time.current)
      initiative.stage_entries.create!(
        stage: :gate_1, iteration: initiative.iteration, qa_cycle: 0,
        status: :active, entered_at: Time.current)
      initiative.update!(current_stage: :gate_1, current_stage_status: :active,
                         stage_changed_at: Time.current)
    end
end
