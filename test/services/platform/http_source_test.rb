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

  # Un proyecto activo por cliente: lo que hace falta para que un lead exista
  # para matrix. Lo que se prueba en cada test es OTRA cosa —la traducción, los
  # sujetos, el contrato—, y sin esto no llegarían ni a empezar.
  def con_proyecto(*client_ids)
    pagina("projects", client_ids.map.with_index(1) do |id, i|
      { "id" => 9000 + i, "ref" => "PRJ-2026-#{9000 + i}", "nombre" => "Un proyecto",
        "client_id" => id, "estado" => "en_curso" }
    end)
  end

  # ── La traducción ──────────────────────────────────────────────────────────

  test "un lead de platform se traduce a un cliente de matrix" do
    clientes, = con_api("projects" => con_proyecto(42),
                        "leads" => pagina("leads", [
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
    clientes, = con_api("projects" => con_proyecto(42),
                        "leads" => pagina("leads", [
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

  # ── Quién existe para matrix ───────────────────────────────────────────────

  test "un lead sin proyecto activo NO es un cliente de matrix" do
    # En platform el cliente *es* el lead, así que su índice trae el embudo
    # comercial entero. Matrix es lo contrario de un CRM: un lead en
    # negociación no tiene nada que evolucionar.
    clientes, = con_api("projects" => con_proyecto(42),
                        "leads" => pagina("leads", [
                          { "id" => 42, "nombre" => "Con trabajo" },
                          { "id" => 43, "nombre" => "En conversación" }
                        ])) { Platform::HttpSource.new.clients }

    assert_equal [ "Con trabajo" ], clientes.map { |c| c[:name] }
  end

  test "un lead admitido SÍ es un cliente de matrix aunque no tenga proyecto" do
    # La excepción se nombra una a una. Es lo que permite reunir la
    # documentación de un cliente mientras su proyecto se prepara, sin devolver
    # el embudo comercial entero.
    clientes, = con_api("projects" => con_proyecto(42),
                        "leads" => pagina("leads", [
                          { "id" => 42, "nombre" => "Con trabajo" },
                          { "id" => 43, "nombre" => "En preparación" }
                        ])) { Platform::HttpSource.new(admitted_ids: [ 43 ]).clients }

    assert_equal [ "Con trabajo", "En preparación" ], clientes.map { |c| c[:name] }
  end

  test "admitir a quien ya tiene trabajo no lo duplica" do
    clientes, = con_api("projects" => con_proyecto(42),
                        "leads" => pagina("leads", [
                          { "id" => 42, "nombre" => "Con trabajo" }
                        ])) { Platform::HttpSource.new(admitted_ids: [ 42 ]).clients }

    assert_equal [ "Con trabajo" ], clientes.map { |c| c[:name] }
  end

  test "sin admisiones el filtro es exactamente el de antes" do
    # La lista vacía es el caso por defecto: quien no pase `admitted_ids` tiene
    # que ver el mismo catálogo que veía antes de que esto existiera.
    clientes, = con_api("projects" => con_proyecto(42),
                        "leads" => pagina("leads", [
                          { "id" => 42, "nombre" => "Con trabajo" },
                          { "id" => 43, "nombre" => "En conversación" }
                        ])) { Platform::HttpSource.new(admitted_ids: []).clients }

    assert_equal [ "Con trabajo" ], clientes.map { |c| c[:name] }
  end

  test "el catálogo de leads los trae TODOS, marcando quién tiene trabajo" do
    # Es lo que enseña `matrix:leads`, y por eso no filtra: existe para ver lo
    # que `#clients` deja fuera y dar el `platform_id` con el que admitir.
    catalogo, = con_api("projects" => con_proyecto(42),
                        "leads" => pagina("leads", [
                          { "id" => 42, "nombre" => "Con trabajo", "estado" => "convertido" },
                          { "id" => 43, "nombre" => "En conversación", "estado" => "negociacion" }
                        ])) { Platform::HttpSource.new.lead_catalog }

    assert_equal [ { platform_id: 42, name: "Con trabajo", status: "convertido", has_work: true },
                   { platform_id: 43, name: "En conversación", status: "negociacion", has_work: false } ],
                 catalogo
  end

  test "el criterio de activo lo pone platform: se pide `projects` sin ampliarlo" do
    # `projects` sin `include_closed` ya devuelve solo planificado, en_curso o
    # pausado, y sin archivar. Duplicar esa lista aquí sería tener dos
    # definiciones de «activo» que algún día dirán cosas distintas.
    _, llamadas = con_api("projects" => pagina("projects", []),
                          "leads" => pagina("leads", [])) do
      Platform::HttpSource.new.clients
    end

    proyectos = llamadas.find { |l| l[:path] == "projects" }
    assert_not_nil proyectos, "no se preguntó qué proyectos hay"
    assert_not proyectos[:params].key?(:include_closed),
               "pedir los cerrados devolvería leads sin trabajo en marcha"
  end

  test "sin ningún proyecto activo no hay clientes, y no revienta" do
    clientes, = con_api("projects" => pagina("projects", []),
                        "leads" => pagina("leads", [
                          { "id" => 42, "nombre" => "Vivla" }
                        ])) { Platform::HttpSource.new.clients }

    assert_empty clientes
  end

  # ── El reparto de sujetos ──────────────────────────────────────────────────

  test "el catálogo va con `system` y las fuentes con `tank`" do
    _, llamadas = con_api(
      "projects" => pagina("projects", []),
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
    # Los dos índices paginan: el de proyectos, que dice quién tiene trabajo, y
    # el de leads. Que el primero se quedara corto escondería clientes.
    api = Class.new do
      def get(path, params = {})
        primera = params[:page] == 1
        filas =
          if path == "projects"
            [ { "id" => primera ? 91 : 92, "ref" => "PRJ-2026-#{primera ? 91 : 92}",
                "client_id" => primera ? 1 : 2, "nombre" => "Un proyecto" } ]
          else
            [ { "id" => primera ? 1 : 2, "nombre" => primera ? "Uno" : "Dos" } ]
          end

        Platform::Api::Response.new(
          status: 200,
          body: { path => filas,
                  "pagination" => { "page" => params[:page], "pages" => 2, "count" => 2,
                                    "next_page" => primera ? 2 : nil } })
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
      con_api("projects" => con_proyecto(42), "leads" => invalido) do
        Platform::HttpSource.new.clients
      end
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
