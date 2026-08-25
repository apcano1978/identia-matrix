require "test_helper"

# El adaptador entre los dos idiomas. Lo que se prueba aquí es la traducción,
# el reparto de sujetos y que un payload malo no llegue a la proyección.
class Platform::HttpSourceTest < ActiveSupport::TestCase
  include DomainBuilders

  # Un doble de `Platform::Api` que registra a quién se le pidió qué. Lo del
  # sujeto no es un detalle: pedir fuentes con `system` da 403 del otro lado, y
  # que cada recurso vaya con el suyo es el mínimo privilegio funcionando.
  class Api
    attr_reader :llamadas

    def initialize(subject, respuestas)
      @subject = subject
      @respuestas = respuestas
      @llamadas = []
    end

    def get(path, params = {})
      @llamadas << { subject: @subject, path: path, params: params }
      cuerpo = @respuestas.fetch(path) { raise "sin respuesta preparada para #{path}" }
      Platform::Api::Response.new(status: 200, body: cuerpo)
    end
  end

  def con_api(respuestas)
    registro = []
    fabrica = lambda do |subject|
      api = Api.new(subject, respuestas)
      registro << api
      api
    end

    resultado = Platform::Api.stub(:for, fabrica) { yield }
    [ resultado, registro.flat_map(&:llamadas) ]
  end

  def pagina(clave, filas) = { clave => filas, "pagination" => { "page" => 1, "pages" => 1, "count" => filas.size, "next_page" => nil } }

  # ── La traducción ──────────────────────────────────────────────────────────

  test "un lead de platform se traduce a un cliente de matrix" do
    clientes, = con_api("leads" => pagina("leads", [
      { "id" => 42, "nombre" => "Vivla", "sector" => "proptech", "ciudad" => "Madrid",
        "estado" => "convertido", "archived" => false,
        "primary_contact" => { "rol" => "cto" } }
    ])) { Platform::HttpSource.new.clients }

    assert_equal({ platform_id: 42, name: "Vivla", sector: "proptech", city: "Madrid",
                   status: "convertido", archived: false, primary_contact_role: "cto" },
                 clientes.first)
  end

  test "el cliente llega con el ROL del contacto y sin su nombre" do
    # Cero PII (F7 §5). Aquí se ve por qué se cumple sin esfuerzo: no hay
    # columna donde caer.
    clientes, = con_api("leads" => pagina("leads", [
      { "id" => 42, "nombre" => "Vivla", "primary_contact" => { "rol" => "cto" } }
    ])) { Platform::HttpSource.new.clients }

    assert_equal "cto", clientes.first[:primary_contact_role]
    assert_not clientes.first.key?(:primary_contact_name)
  end

  test "un proyecto llega con el cliente ya aplanado" do
    proyectos, = con_api("projects" => pagina("projects", [
      { "id" => 2291, "ref" => "PRJ-2026-9001", "nombre" => "Unificar precios",
        "client_id" => 42, "estado" => "en_curso", "fase_actual" => "design",
        "fecha_inicio" => "2026-05-01", "fecha_fin_estimada" => "2026-07-01" }
    ])) { Platform::HttpSource.new.projects }

    proyecto = proyectos.first
    assert_equal "PRJ-2026-9001", proyecto[:platform_project_ref]
    assert_equal 42, proyecto[:client_platform_id]
    assert_equal "Unificar precios", proyecto[:name]
  end

  # ── El reparto de sujetos ──────────────────────────────────────────────────

  test "el catálogo va con `system` y las fuentes con `tank`" do
    _, llamadas = con_api(
      "leads" => pagina("leads", []),
      "meetings" => pagina("meetings", [])
    ) do
      Platform::HttpSource.new.clients
      Platform::HttpSource.new.meetings
    end

    por_recurso = llamadas.to_h { |l| [ l[:path], l[:subject] ] }
    assert_equal :system, por_recurso["leads"]
    assert_equal :tank, por_recurso["meetings"], "las fuentes son de TANK, no de la sincronización"
  end

  # ── Índice y detalle ───────────────────────────────────────────────────────

  test "el índice descubre y el detalle trae el cuerpo, solo de lo que cambió" do
    indice = pagina("client_documents", [
      { "id" => 5001, "titulo" => "Acta", "lead_id" => 42, "project_id" => nil,
        "updated_at" => "2026-05-02T08:40:00+02:00" }
    ])
    detalle = { "id" => 5001, "titulo" => "Acta", "lead_id" => 42,
                "cuerpo" => "El precio sube un 4 %.", "adjuntos" => [],
                "updated_at" => "2026-05-02T08:40:00+02:00" }

    documentos, llamadas = con_api("client_documents" => indice,
                                   "client_documents/5001" => detalle) do
      Platform::HttpSource.new.documents
    end

    assert_equal "El precio sube un 4 %.", documentos.first[:body]
    assert_includes llamadas.map { |l| l[:path] }, "client_documents/5001"
  end

  test "lo que no ha cambiado no se vuelve a descargar" do
    # Sin esto, un latido de quince minutos se bajaría el cuerpo de todos los
    # documentos del cliente cada vez.
    client = build_client
    Platform::Record.writing do
      Platform::Document.create!(platform_id: 5001, platform_client: client,
                                 slug: "acta", title: "Acta",
                                 source_updated_at: Time.zone.parse("2026-05-02T08:40:00+02:00"))
    end

    indice = pagina("client_documents", [
      { "id" => 5001, "titulo" => "Acta", "lead_id" => client.platform_id,
        "updated_at" => "2026-05-02T08:40:00+02:00" }
    ])

    documentos, llamadas = con_api("client_documents" => indice) do
      Platform::HttpSource.new.documents
    end

    assert_nil documentos.first[:body], "no se pidió el detalle, así que no hay cuerpo"
    assert_not_includes llamadas.map { |l| l[:path] }, "client_documents/5001"
  end

  test "recorre todas las páginas del índice, siguiendo next_page" do
    # Para indexar un cliente entero hace falta recorrerlo completo: el tope
    # duro del otro lado son 200 filas.
    api = Class.new do
      def get(_path, params = {})
        cuerpo =
          if params[:page] == 1
            { "leads" => [ { "id" => 1, "nombre" => "Uno" } ],
              "pagination" => { "page" => 1, "pages" => 2, "count" => 2, "next_page" => 2 } }
          else
            { "leads" => [ { "id" => 2, "nombre" => "Dos" } ],
              "pagination" => { "page" => 2, "pages" => 2, "count" => 2, "next_page" => nil } }
          end
        Platform::Api::Response.new(status: 200, body: cuerpo)
      end
    end.new

    clientes = Platform::Api.stub(:for, ->(_) { api }) { Platform::HttpSource.new.clients }

    assert_equal [ 1, 2 ], clientes.map { |c| c[:platform_id] },
                 "se quedó en la primera página"
  end

  # ── El contrato ────────────────────────────────────────────────────────────

  test "un payload que no cumple el contrato NO llega a la proyección" do
    # Es preferible una sincronización que no corre a una que deja la proyección
    # a medias, porque lo segundo no se ve.
    invalido = pagina("leads", [ { "nombre" => "Sin id" } ])

    assert_raises(Contracts::ValidationError) do
      con_api("leads" => invalido) { Platform::HttpSource.new.clients }
    end
  end

  test "una respuesta que no es 200 revienta en vez de devolver una lista vacía" do
    api = Struct.new(:x) do
      def get(_path, _params = {}) = Platform::Api::Response.new(status: 403, body: {})
    end.new(nil)

    error = assert_raises(Platform::Api::Unexpected) do
      Platform::Api.stub(:for, ->(_) { api }) { Platform::HttpSource.new.meetings }
    end

    assert_includes error.message, "403"
  end
end
