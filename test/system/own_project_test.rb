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
    fill_in "slug", with: "proyecto-de-prueba"
    fill_in "name", with: "Proyecto de prueba"
    click_on "ABRIR EL PROYECTO ⏎"

    assert_current_path project_path("proyecto-de-prueba")
    assert_selector "h1", text: "Proyecto de prueba"
    assert_text "PROPIO"
    assert_text "proyecto propio · nada que sincronizar"
    assert Project.find_by!(slug: "proyecto-de-prueba").own?
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
    fill_in "name", with: "Proyecto de prueba"
    click_on "ABRIR EL PROYECTO ⏎"

    assert_text "claves de artefacto"
    assert_nil Project.find_by(name: "Proyecto de prueba")
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
    open_proyecto_de_prueba

    assert_text "Para abrir un evolutivo hace falta al menos un repositorio"

    find("summary", text: "registrar un repositorio").click
    fill_in "name", with: "identia-matrix"
    click_on "registrar ⏎"

    assert_current_path project_repository_path("proyecto-de-prueba", "identia-matrix")
    assert_text "registro · nada que atender"

    visit project_path("proyecto-de-prueba")
    find("summary", text: "abrir un evolutivo").click
    fill_in "title", with: "Rediseño de la interfaz"
    check "repo-#{repo_of('proyecto-de-prueba', 'identia-matrix').id}"
    click_on "abrir ⏎"

    assert_text "Rediseño de la interfaz"
    assert_text "PIPELINE"
  end

  # `initiatives_helper#artifact_tabs` y el panel del evolutivo. Los dos leían el
  # cliente: el primero para construir las rutas de las tres pestañas de
  # evidencia, el segundo para pintar la fila «cliente».
  test "la ficha del evolutivo se pinta, y su panel dice el proyecto en vez del cliente" do
    initiative = own_initiative

    visit project_initiative_path("proyecto-de-prueba", initiative.slug)

    assert_text "PIPELINE"
    panel = find("[data-pane='meta']")

    assert panel.has_text?("proyecto"), "el panel nombra la raíz"
    assert panel.has_text?("Proyecto de prueba")
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
    assert_text "proyecto-de-prueba/identia-matrix"
    assert_selector "a[href='#{project_initiative_gate_1_path('proyecto-de-prueba', initiative.slug)}']"
  end

  # Un proyecto propio no hereda documentación de ningún cliente, y eso NO es un
  # hueco: es la frontera funcionando. La consulta sale con `platform_client_id`
  # nulo y devuelve vacío, que es lo correcto.
  test "sus fuentes no fingen heredar de nadie" do
    initiative = own_initiative

    visit project_initiative_sources_path("proyecto-de-prueba", initiative.slug)

    assert_text "Fuentes en ámbito"
    assert_text "identia-matrix"
    assert_no_text "HEREDADAS DE"
    assert_no_text "acta-precios"
  end

  # ⚠ F12 · Y LO QUE ARREGLA ESE VACÍO. Hasta B4 esta pantalla no tenía nada que
  # enseñarle a un proyecto propio: sin cliente detrás, ninguna sección se podía
  # llenar nunca. Los documentos SUBIDOS son su única fuente posible, y salen por
  # la sección DEL PROYECTO.
  test "pero lo que se le sube sí sale, que es su única fuente posible" do
    initiative = own_initiative
    upload_document_to("proyecto-de-prueba")

    visit project_initiative_sources_path("proyecto-de-prueba", initiative.slug)

    documentos = find("[data-card='docs-proyecto']")

    assert documentos.has_text?("acta-arranque")
    assert_text "subidos a proyecto-de-prueba"
    assert_no_text "HEREDADAS DE"
  end

  # Sin cuerpo NO viaja al agente —`Runtime::Request` filtra por `citable?`— y la
  # pantalla lo dice en vez de listarlo como si sirviera.
  test "y el que todavía no tiene cuerpo se lista diciendo que no viaja" do
    initiative = own_initiative
    upload_document_to("proyecto-de-prueba", extract: false)

    visit project_initiative_sources_path("proyecto-de-prueba", initiative.slug)

    documentos = find("[data-card='docs-proyecto']")

    assert documentos.has_text?("acta-arranque")
    assert documentos.has_text?("sin cuerpo · no viaja")
  end

  # El formulario de evolutivo no enseña un desplegable vacío: dice por qué no
  # hay ninguno al otro lado.
  test "el alta de evolutivo no ofrece vincular con platform, y lo explica" do
    open_proyecto_de_prueba
    build_repository_through_screen

    visit project_path("proyecto-de-prueba")
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

    assert_equal({ "slug" => "proyecto-de-prueba", "name" => "Proyecto de prueba" },
                 config["project"])
    assert_not config.key?("client"),
               "la clave se OMITE, no se manda a null: el contrato espera un objeto"
  end

  test "y la ficha ofrece el botón, que es lo que B7b no podía" do
    initiative = own_initiative
    place(initiative, :tank)

    visit project_initiative_path("proyecto-de-prueba", initiative.slug)

    assert_button "▶ poner a trabajar a TANK"
    assert_no_text "Los agentes todavía no trabajan sobre proyectos propios"
  end

  # ══ EL ENTREGABLE DE F11 ═══════════════════════════════════════════════════
  #
  # `identia-interno` es el proyecto propio de verdad: identia trabajando sobre
  # sí misma, repartida entre sus tres repositorios. Lo siembra `DesignSeed` sin
  # evolutivos, que es el estado con el que nace un proyecto.
  #
  # Este test recorre lo que once bloques construyeron —abrir el evolutivo,
  # contarle la idea al ARQUITECTO, cerrar el acta, poner a trabajar a TANK— y
  # termina en la única aserción que resume la fase entera: **la clave del
  # artefacto empieza por el nombre del proyecto y el del evolutivo**, ninguno de
  # los cuales existía antes de F11.

  test "identia-interno nace sembrado, propio y multi-repo, sin un solo evolutivo" do
    visit projects_path(tab: "propios")

    assert_text "PROPIOS · 1"
    assert_text "IDENTIA INTERNO"
    assert_text "Todavía no tiene ningún evolutivo"

    click_on "IDENTIA INTERNO"
    assert_selector "h1", text: "IDENTIA INTERNO"
    assert_text "PROPIO"
    assert_text "proyecto propio · nada que sincronizar"
    # Los tres repositorios de identia, que es lo que lo hace multi-repo desde el
    # primer día y no un ensayo con uno.
    %w[identia-matrix identia-brain identia-platform].each { |repo| assert_text repo }
  end

  test "y recorre la fase entera hasta publicar con su propia clave" do
    # 1 · El evolutivo, sobre el repositorio que se va a tocar.
    visit project_path("identia-interno")
    find("summary", text: "abrir un evolutivo").click
    fill_in "title", with: "Rediseño de la interfaz"
    check "repo-#{repo_of('identia-interno', 'identia-matrix').id}"
    click_on "abrir ⏎"
    assert_text "PIPELINE"

    # ⚠ El slug se DERIVA del título —solo el del proyecto se escribe a mano—,
    # así que «Rediseño de la interfaz» da `rediseno-de-la-interfaz`. La guía usa
    # `rediseno-interfaz` como ilustración; lo que la clave lleva dentro es esto.
    initiative = Initiative.find_by!(slug: "rediseno-de-la-interfaz")

    # 2 · La idea, por el acta. Es la única fuente de nivel ORIGEN que un
    #     proyecto propio tiene hasta F12, y ya es citable.
    visit project_initiative_acta_path("identia-interno", initiative.slug)
    assert_text "Todavía no hay ninguna decisión"
    fill_in "message", with: "Hay que rehacer la interfaz sobre el proyecto como raíz."
    click_on "Responder al ARQUITECTO"
    assert_text "Turno registrado"
    assert_selector "[data-decision='1']"

    # 3 · Cerrar el acta saca de la etapa 1 y entra en TANK.
    click_on "CERRAR Y PASAR A TANK"
    # ⚠ La barrera es el PATH, no el texto. «entra en TANK» ya está en el panel
    # de cerrar antes de pulsar —«Publica el acta y el evolutivo entra en TANK»—
    # así que esperar por él daba por buena la pantalla anterior. Es la misma
    # familia de fallo que P18: la barrera tiene que ser algo que solo existe
    # en el destino.
    assert_current_path project_initiative_path("identia-interno", initiative.slug)
    assert_predicate initiative.reload, :at_tank?

    # 4 · ANCLAR E INDEXAR, que es el paso que el runbook avisa que se olvida.
    #
    # ⚠ Sin él `pinned_sha` queda nulo, `Runtime::Request#repositories_of` —que
    # solo manda los ANCLADOS— deja el material vacío y **TANK trabaja a ciegas
    # sin que nada avise**. Que se encole solo es F12; hasta entonces es un paso
    # a mano, y por eso está aquí y no escondido en un helper.
    Repositories::Index.call(initiative: initiative, actor: "test")

    assert initiative.initiative_repositories.reload.all? { |link| link.pinned_sha.present? },
           "sin sha anclado no se puede citar código, y TANK no lo diría"

    # 5 · TANK, en `fake`.
    #
    # ⚠ Por `Agents::Run` y no pulsando el botón: el botón encola por Sidekiq y
    #    en test el adaptador NO corre en línea. Es el mismo objeto que llama el
    #    job, y que el botón encola está probado aparte.
    artifact = Agents::Run.call(initiative: initiative, agent: "tank",
                                purpose: "context").artifact

    # 6 · LA ASERCIÓN DE LA FASE. Antes de F11 la clave habría sido
    # `artifacts://<cliente>/ev-NNN/…`, y aquí no hay cliente ni código.
    assert artifact.storage_key.start_with?(
      "artifacts://identia-interno/rediseno-de-la-interfaz/"),
           "la clave tiene que llevar el proyecto y el nombre: #{artifact.storage_key}"

    # Y el acta, publicada por el mismo camino, con la misma raíz.
    acta = initiative.artifacts.kind_acta.sole

    assert acta.storage_key.start_with?("artifacts://identia-interno/rediseno-de-la-interfaz/")
    assert_nil acta.stored_front_matter[:client], "no hay cliente, y no se inventa"
    assert_equal "identia-interno", acta.stored_front_matter[:project]
  end

  private
    # ⚠ Acotado al PROYECTO: `identia-matrix` es un repositorio del proyecto
    # sembrado Y del de prueba, y un `find_by!(name:)` a secas elegiría uno de
    # los dos por orden de inserción.
    def repo_of(project_slug, name)
      Project.find_by!(slug: project_slug).repositories.find_by!(name: name)
    end

    def open_proyecto_de_prueba
      Projects::Open.call(slug: "proyecto-de-prueba", name: "Proyecto de prueba",
                          actor: "test")
      visit project_path("proyecto-de-prueba")
      assert_selector "h1", text: "Proyecto de prueba"
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
      project = Projects::Open.call(slug: "proyecto-de-prueba", name: "Proyecto de prueba",
                                    actor: "test")
      repository = Repository.create!(project: project, name: "identia-matrix",
                                      default_branch: "main")

      Initiatives::Open.call(project: project, title: "Rediseño de la interfaz",
                             repositories: [ repository ], actor: "test")
    end

    # Sube un documento por la pantalla del proyecto, que es la única forma que
    # hay: no se fabrica la fila a mano porque lo que se quiere probar es el
    # camino entero, desde el fichero hasta la pantalla de fuentes.
    #
    # La extracción es un job y en test el adaptador es el de Sidekiq, así que
    # `perform_later` encola de verdad: se corre a mano, que es lo que hará el
    # worker. Sin `extract:` queda el estado intermedio que el usuario ve.
    def upload_document_to(project_slug, extract: true)
      path = Rails.root.join("tmp", "acta arranque.md")
      path.write("# Acta de arranque\n\nLo acordado en el arranque.\n")

      visit project_path(project_slug)
      attach_file "files[]", path.to_s
      assert_no_text "Todavía no hay ninguno"

      return unless extract

      ProjectDocument.where(extracted_at: nil).find_each do |document|
        ProjectDocuments::Extract.call(document)
      end
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
