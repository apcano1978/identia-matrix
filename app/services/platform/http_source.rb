# La fuente real: `GET /internal/v1/...` contra identia-platform, con el
# contrato `matrix-platform/read.v1.json`.
#
# Devuelve exactamente lo mismo que `Platform::FakeSource` —cinco listas de
# hashes planos— para que `Platform::Projection` no sepa si detrás hay un
# fichero o una llamada HTTP. Toda la diferencia entre los dos sistemas cabe
# aquí dentro.
#
# **Es el adaptador de nombres.** El contrato habla el idioma de platform —`id`,
# `nombre`, `titulo`, `fecha`— y el dominio de matrix el suyo —`platform_id`,
# `name`, `title`, `held_on`—. La traducción vive en un solo sitio, que es este.
#
# **Dos sujetos, no uno.** Clientes, proyectos y usuarios van con el token de
# `matrix:system`; documentos y transcripciones con el de `matrix:tank`. Pedir
# fuentes con `system` devuelve 403, y eso es el mínimo privilegio funcionando,
# no un error de configuración.
#
# **No toca la base de datos.** Ni siquiera para el slug: eso es de `Projection`,
# que es quien puede resolver una colisión.
class Platform::HttpSource
  # Cuántas filas por página al recorrer un índice. El tope duro del otro lado
  # es 200; se pide menos para que una respuesta no crezca sin control.
  PER_PAGE = 100

  # Sin cliente, trae todo. Con cliente, solo sus proyectos y sus fuentes: nunca
  # una pasada que mezcle dos.
  #
  # Clientes y usuarios NO se acotan aunque haya cliente: quién existe y quién
  # tiene acceso son hechos globales, sus índices no traen cuerpo y salen
  # baratos. Acotarlos haría además que sincronizar un cliente marcara como
  # ausentes a todos los demás.
  # `admitted_ids` llega YA RESUELTO desde fuera —`Platform::Source`— y no se
  # consulta aquí: esta clase habla HTTP y no toca la base de datos, que es lo
  # que permite que `Projection` no sepa si detrás hay un fichero o una llamada.
  def initialize(client_platform_id: nil, admitted_ids: [])
    @client_platform_id = client_platform_id
    @admitted_ids = admitted_ids.to_set
  end

  def name = "platform"

  # **Un cliente de matrix es un lead CON TRABAJO EN MARCHA**, no cualquier lead.
  # En platform el cliente *es* el lead (F7 §2.3), así que su índice trae el
  # embudo comercial entero —incluidos los perdidos—, y matrix es lo contrario
  # de un CRM: un sistema de evolutivos sobre código que ya existe. Un lead en
  # negociación no tiene nada que evolucionar.
  #
  # El criterio de «activo» NO se decide aquí: `projects` sin `include_closed`
  # ya devuelve solo los activos —planificado, en_curso o pausado, y sin
  # archivar—. Lo pone platform, que es de quien es el dato; duplicarlo sería
  # tener dos definiciones que algún día dirán cosas distintas.
  #
  # No se acota por `@client_platform_id` a propósito: quién existe es un hecho
  # global, y acotarlo marcaría como ausentes a todos los demás (ver `initialize`).
  # **Y las excepciones se nombran una a una.** `ClientAdmission` deja entrar a un
  # cliente concreto que todavía no tiene proyecto, para poder reunir su
  # documentación mientras el trabajo se prepara. Es una lista de nombres
  # propios y no un criterio más ancho: ensanchar el criterio devolvería el
  # embudo comercial entero, que es de lo que este filtro existe para librarnos.
  def clients
    admisibles = clients_with_work | @admitted_ids

    index(:system, "leads").select { |lead| admisibles.include?(lead["id"]) }.map do |lead|
      {
        platform_id: lead["id"],
        name: lead["nombre"],
        sector: lead["sector"],
        city: lead["ciudad"],
        status: lead["estado"],
        archived: lead["archived"] || false,
        # SOLO EL ROL, sin nombre. Es la regla de cero PII de F7 §5, y aquí se
        # ve por qué se puede cumplir sin esfuerzo: no hay columna donde caer.
        primary_contact_role: lead.dig("primary_contact", "rol")
      }
    end
  end

  # El catálogo SIN filtrar, con la marca de quién tiene trabajo. No lo usa la
  # proyección —que solo quiere clientes— sino `matrix:leads`, que existe para
  # enseñar precisamente lo que `#clients` deja fuera, y para dar el
  # `platform_id` con el que admitir a alguien.
  def lead_catalog
    con_trabajo = clients_with_work

    index(:system, "leads").map do |lead|
      {
        platform_id: lead["id"],
        name: lead["nombre"],
        status: lead["estado"],
        has_work: con_trabajo.include?(lead["id"])
      }
    end
  end

  def users
    index(:system, "users").map do |user|
      {
        platform_id: user["id"],
        email_address: user["email_address"],
        name: user["name"],
        role: user["role"],
        cargo: user["cargo"],
        disabled: user["disabled"]
      }
    end
  end

  def projects
    index(:system, "projects", params: scoped(lead_id: @client_platform_id)).map do |project|
      {
        platform_id: project["id"],
        platform_project_ref: project["ref"],
        name: project["nombre"],
        client_platform_id: project["client_id"],
        status: project["estado"],
        current_phase: project["fase_actual"],
        started_on: project["fecha_inicio"],
        estimated_end_on: project["fecha_fin_estimada"]
      }
    end
  end

  def documents
    sources(:client_documents, Platform::Document) do |row, detail|
      {
        platform_id: row["id"],
        title: row["titulo"],
        client_platform_id: row["lead_id"],
        project_platform_id: row["project_id"],
        body: detail&.dig("cuerpo"),
        source_updated_at: row["updated_at"]
      }
    end
  end

  def meetings
    sources(:meetings, Platform::Meeting) do |row, detail|
      {
        platform_id: row["id"],
        title: row["titulo"],
        held_on: row["fecha"],
        client_platform_id: row["lead_id"],
        project_platform_id: row["project_id"],
        body: detail&.dig("cuerpo"),
        source_updated_at: row["updated_at"]
      }
    end
  end

  private

  # Quién tiene trabajo en marcha. El criterio de «activo» NO se decide aquí:
  # `projects` sin `include_closed` ya devuelve solo los activos.
  def clients_with_work
    index(:system, "projects").filter_map { |project| project["client_id"] }.to_set
  end

  # El índice descubre qué hay y qué cambió; el detalle trae el cuerpo. Es la
  # regla de forma de F7 §3.1, y aquí está su razón de ser: sin ella, un latido
  # de quince minutos se bajaría de S3 el cuerpo de todos los documentos del
  # cliente cada vez.
  def sources(resource, model)
    rows = index(:tank, resource.to_s, params: scoped(lead_id: @client_platform_id))
    conocido = model.where(platform_id: rows.map { |r| r["id"] }).pluck(:platform_id, :source_updated_at).to_h

    rows.map do |row|
      detail = detail(:tank, resource, row["id"]) if changed?(row, conocido)
      yield(row, detail)
    end
  end

  # Sin `source_updated_at` guardado, es nuevo. Con uno anterior, cambió. La
  # comparación es sobre el instante, no sobre la cadena: platform serializa con
  # su huso y una comparación de texto diría que todo cambia siempre.
  def changed?(row, conocido)
    visto = conocido[row["id"]]
    return true if visto.nil?

    Time.zone.parse(row["updated_at"].to_s) > visto
  end

  # Recorre el índice entero por páginas. Matrix pide SIEMPRE página, aunque
  # haya una sola: es lo que hace que el objeto `pagination` esté siempre ahí y
  # que el contrato lo pueda exigir.
  def index(subject, resource, params: {})
    rows = []
    page = 1

    loop do
      payload = get(subject, resource, params.merge(page: page, per_page: PER_PAGE))
      rows.concat(payload.fetch(resource))
      page = payload.dig("pagination", "next_page")
      break if page.nil?
    end

    rows
  end

  def detail(subject, resource, id) = get(subject, "#{resource}/#{id}")

  # **Se valida antes de traducir, no después.** Un payload que no cumple aborta
  # este recurso entero: es preferible una sincronización que no corre a una que
  # deja la proyección a medias, porque lo segundo no se ve.
  def get(subject, path, params = {})
    response = Platform::Api.for(subject).get(path, params)

    unless response.ok?
      raise Platform::Api::Unexpected,
            "platform devolvió #{response.status} en #{path} con el sujeto #{subject}"
    end

    Contracts.validate!(:matrix_platform_read, response.body)
  end

  # Sin cliente, la sincronización es de todo. Con cliente, solo lo suyo:
  # nunca una pasada que mezcle dos.
  def scoped(params) = @client_platform_id ? params : {}
end
