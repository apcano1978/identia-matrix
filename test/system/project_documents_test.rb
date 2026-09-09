require "application_system_test_case"

# Subir documentos a un proyecto, desde la pantalla. Es la primera vez que matrix
# acepta un fichero.
#
# Lo que se prueba aquí no es que se guarde —eso es del servicio— sino **que los
# tres estados se leen** y que la pantalla no ofrece lo que no puede dar: el
# fichero original no se descarga desde ninguna parte.
class ProjectDocumentsTest < ApplicationSystemTestCase
  setup do
    DesignSeed.call
    sign_in_as Platform::User.find_by!(platform_id: 1)
  end

  test "un proyecto sin documentos dice de dónde se parte" do
    visit project_path("identia-interno")

    assert_text "## DOCUMENTOS"
    assert_text "Arrastra documentos aquí"
    assert_text "markdown, pdf, csv o transcripciones · se quedan dentro de este proyecto"
    assert_text "Todavía no hay ninguno"
    # El aviso literal del rediseño: es la mitad de por qué esta pantalla existe.
    assert_text "nace sin cita de origen y MORFEO lo verá como derivado"
  end

  # LOS DOS ESTADOS QUE SE VEN, en el orden en que se ven. Al volver de subir la
  # extracción todavía no ha corrido —es un job, y ese es todo el sentido del
  # bloque anterior— así que la pantalla dice «extrayendo texto», que es lo que
  # el rediseño pinta.
  test "se sube un markdown y la pantalla dice que se está extrayendo" do
    upload("con-texto.md")

    assert_text "1 documento subido"
    assert_text "el texto se extrae en un momento"

    fila = find("[data-document='con-texto']")

    assert fila.has_text?("◆ con-texto")
    assert fila.has_text?("extrayendo texto")
    assert fila.has_text?("no citable todavía")
  end

  test "y cuando el job termina, queda citable con su cita compuesta" do
    upload("con-texto.md")
    extract_pending

    visit project_path("identia-interno")
    fila = find("[data-document='con-texto']")

    assert fila.has_text?("● con-texto")
    assert fila.has_text?("citable")
    assert fila.has_text?("◆ origen")
    assert fila.has_text?("[src:doc/con-texto]")
    assert fila.has_text?("Una única autoridad de precio")
  end

  # Un PDF escaneado NO es un fallo: es un caso real, y la pantalla lo dice en vez
  # de fingir un cuerpo vacío.
  test "y un pdf sin capa de texto se queda sin cuerpo, diciéndolo" do
    upload("escaneado.pdf", type: "application/pdf")
    extract_pending

    visit project_path("identia-interno")
    fila = find("[data-document='escaneado']")

    assert fila.has_text?("sin cuerpo extraído")
    assert fila.has_text?("probablemente esté escaneado")
    assert fila.has_text?("no citable todavía")
    assert fila.has_no_text?("◆ origen")
  end

  # ⚠ LA DECISIÓN DEL BLOQUE, hecha test. Matrix enseña TEXTO, nunca ficheros: el
  # visor renderiza markdown y la ficha de cliente lista sus documentos sin un
  # solo enlace. `ArtifactAccess` cierra además la puerta del proxy de Active
  # Storage a todo lo que no sea un artefacto, así que un enlace aquí llevaría a
  # un 404.
  test "y no hay ni un enlace al fichero original" do
    upload("con-texto.md")

    assert_no_selector "a[href*='/rails/active_storage']"
    assert_no_selector "a", text: "descargar"
  end

  test "retirar lo saca de la lista y lo deja escrito" do
    upload("con-texto.md")
    accept_confirm { click_on "retirar" }

    assert_text "Sale del ámbito de los evolutivos nuevos"
    assert_no_selector "[data-document='con-texto']"

    retirado = find("[data-retired='con-texto']")

    assert retirado.has_text?("sigue resolviendo las citas ya emitidas")
  end

  test "el que se pasa de 25 MB no entra, y la pantalla dice por qué" do
    # Sin escribir 25 MB en disco: se comprueba el mensaje que el servicio
    # compone, que es lo que la pantalla enseña.
    # Sin el helper: su barrera es que la lista deje de estar vacía, y con un
    # rechazo no cambia nada — que es justo lo que este test comprueba.
    ProjectDocuments::Upload.stub(:call, ->(**) {
      raise ProjectDocuments::Upload::Refused, "volcado.csv pesa 40 MB y el tope son 25 MB"
    }) do
      visit project_path("identia-interno")
      attach_file "files", fixture_path_for("con-texto.md", "text/markdown")
      assert_text "No se ha subido nada"
    end

    assert_text "el tope son 25 MB"
    assert_text "Todavía no hay ninguno"
  end

  private
    # El job no corre en línea: el adaptador de Active Job en test es el de
    # Sidekiq, así que `perform_later` encola de verdad. Se ejecuta lo pendiente
    # a mano, que es lo mismo que hará el worker.
    def extract_pending
      ProjectDocument.where(extracted_at: nil).find_each do |document|
        ProjectDocuments::Extract.call(document)
      end
    end

    def upload(name, type: "text/markdown")
      visit project_path("identia-interno")
      # ⚠ `attach_file` necesita el input ALCANZABLE. Está visible a propósito:
      # es lo que hace que la subida funcione sin JS, y ocultarlo para dejar solo
      # la zona de arrastre dejaría esta pantalla sin forma de probarse.
      #
      # Por ID y no por nombre: desde B5 el alta de un evolutivo tiene su propio
      # `files[]` en esta misma pantalla, y buscar por nombre sería ambiguo.
      attach_file "files", fixture_path_for(name, type)
      assert_no_text "Todavía no hay ninguno"
    end

    # Los PDF son fixtures de verdad; el markdown se escribe al vuelo.
    def fixture_path_for(name, type)
      return Rails.root.join("test/fixtures/files", name).to_s if type == "application/pdf"

      path = Rails.root.join("tmp", name)
      path.write("# Acta de precios\n\nUna única autoridad de precio.\n")
      path.to_s
    end
end
