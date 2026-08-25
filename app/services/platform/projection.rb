# Importa lo que devuelve una fuente a las cinco tablas de la proyección.
#
# Es la mitad que NO cambia en F8: allí se enchufa `Platform::HttpSource` en
# lugar de `Platform::FakeSource` y esto sigue igual. Por eso la fuente devuelve
# hashes planos y no toca la base de datos.
#
# Cuatro reglas que se cumplen aquí y en ningún otro sitio:
#
#   · Se escribe SOLO dentro de `Platform::Record.writing`.
#   · El `slug` NO se refresca: va dentro de claves de artefacto inmutables y de
#     citas ya emitidas. Se congela en la primera sincronización — y si la
#     fuente no lo trae, se DERIVA aquí (F8), porque resolver una colisión exige
#     mirar la base de datos y una fuente no la toca.
#   · Lo que desaparece del origen se marca con `missing_since`; no se borra.
#   · Y eso se decide dentro de un ÁMBITO: una sincronización por cliente no
#     puede marcar como ausente lo de los demás (F8).
module Platform::Projection
  # Congelados en el primer alta. Cambiarlos rompería citas ya emitidas.
  FROZEN = %w[slug platform_id].freeze

  Report = Data.define(:created, :updated, :missing) do
    def to_s = "#{created} nuevos · #{updated} actualizados · #{missing} ausentes"
  end

  module_function

  # Las cinco tablas, en orden de dependencia: un documento necesita que su
  # cliente exista para poder resolver la referencia.
  TABLES = {
    clients: Platform::Client,
    users: Platform::User,
    projects: Platform::Project,
    documents: Platform::Document,
    meetings: Platform::Meeting
  }.freeze

  # `only` limita qué tablas se tocan y `client` acota lo que se considera
  # ausente dentro de ellas. Los dos existen por la misma razón: una fila que no
  # se ha mirado no puede quedar sellada como si se hubiera mirado, ni marcada
  # como ausente por no haberse pedido.
  def import(source = Platform::Source.current, client: nil, only: TABLES.keys)
    Platform::Record.writing do
      only.map do |table|
        model = TABLES.fetch(table)
        upsert(model, source.public_send(table), source.name,
               scope: owned(model, client))
      end.reduce { |a, b| combine(a, b) }
    end
  end

  # Nulo cuando no hay cliente: entonces la pasada es de todo y «lo que ya no
  # viene» se mide contra la tabla entera, que es lo correcto.
  def owned(model, client)
    return nil if client.nil? || !model.column_names.include?("platform_client_id")

    model.where(platform_client_id: client.id)
  end

  # `scope` acota QUÉ se considera ausente. Sin él, sincronizar un solo cliente
  # marcaría como desaparecido todo lo de los demás —que no vino porque no se
  # pidió, no porque no exista—, y el ámbito de sus evolutivos se vaciaría en
  # silencio. Nulo significa «la tabla entera», que es lo que hace el seed.
  def upsert(model, records, source_name, scope: nil)
    created = 0
    updated = 0
    seen = []

    records.each do |attributes|
      attributes = resolve_references(model, attributes)
      row = model.find_or_initialize_by(platform_id: attributes[:platform_id])

      if row.new_record?
        row.assign_attributes(attributes)
        assign_slug(row, attributes)
        created += 1
      else
        row.assign_attributes(attributes.except(*FROZEN.map(&:to_sym)))
        updated += 1 if row.changed?
      end

      row.synced_at = Time.current
      row.sync_source = source_name
      row.missing_since = nil
      row.save!
      seen << row.platform_id
    end

    Report.new(created: created, updated: updated,
               missing: mark_missing(model, seen, scope))
  end

  # De dónde sale el slug de cada tabla. Un documento y una reunión tienen
  # `title`; un cliente tiene `name`. Escrito y no adivinado: la primera versión
  # buscaba solo `title`, y los clientes reales salieron todos como
  # `client-1`, `client-2`… — que es el respaldo, y el slug de cliente es el
  # segmento de las CLAVES DE ARTEFACTO. Congelado y mal.
  SLUG_FROM = { "Platform::Client" => :name,
                "Platform::Document" => :title,
                "Platform::Meeting" => :title }.freeze

  # El slug solo se asigna al CREAR, y solo si la fuente no lo trae. La falsa lo
  # trae —son los de la maqueta, y son parte de lo que se quiere reproducir—;
  # platform no, porque el slug es propiedad de matrix.
  def assign_slug(row, attributes)
    campo = SLUG_FROM[row.class.name]
    return if campo.nil? || attributes[:slug].present?

    row.slug = Platform::Slug.derive(
      row.class, attributes[campo],
      fallback: "#{row.class.name.demodulize.downcase}-#{attributes[:platform_id]}")
  end

  # Lo que ya no viene del origen se MARCA, no se borra. Es el invariante 1 por
  # su lado menos obvio: una cita ya emitida tiene que seguir resolviendo dentro
  # de un artefacto que nadie puede reescribir, y para eso la fila tiene que
  # seguir existiendo aunque el documento haya desaparecido de platform.
  #
  # Estaba escrito en el comentario de esta clase desde F2 y no estaba hecho: el
  # informe devolvía siempre `missing: 0`.
  def mark_missing(model, seen, scope = nil)
    gone = (scope || model).where.not(platform_id: seen).where(missing_since: nil)

    gone.count.tap { gone.update_all(missing_since: Time.current) }
  end

  # La fuente habla en platform_id, que es lo único estable entre los dos
  # sistemas. Aquí se traduce a la clave local.
  def resolve_references(model, attributes)
    attributes = attributes.dup

    if (platform_id = attributes.delete(:client_platform_id))
      attributes[:platform_client_id] =
        Platform::Client.find_by!(platform_id: platform_id).id
    end

    if (platform_id = attributes.delete(:project_platform_id))
      attributes[:platform_project_id] =
        Platform::Project.find_by(platform_id: platform_id)&.id
    end

    attributes
  end

  def combine(a, b)
    Report.new(created: a.created + b.created, updated: a.updated + b.updated,
               missing: a.missing + b.missing)
  end
end
