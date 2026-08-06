# Importa lo que devuelve una fuente a las cinco tablas de la proyección.
#
# Es la mitad que NO cambia en F8: allí se enchufa `Platform::HttpSource` en
# lugar de `Platform::FakeSource` y esto sigue igual. Por eso la fuente devuelve
# hashes planos y no toca la base de datos.
#
# Tres reglas que se cumplen aquí y en ningún otro sitio:
#
#   · Se escribe SOLO dentro de `Platform::Record.writing`.
#   · El `slug` NO se refresca: va dentro de claves de artefacto inmutables y de
#     citas ya emitidas. Se congela en la primera sincronización.
#   · Lo que desaparece del origen se marca con `missing_since`; no se borra.
module Platform::Projection
  # Congelados en el primer alta. Cambiarlos rompería citas ya emitidas.
  FROZEN = %w[slug platform_id].freeze

  Report = Data.define(:created, :updated, :missing) do
    def to_s = "#{created} nuevos · #{updated} actualizados · #{missing} ausentes"
  end

  module_function

  def import(source = Platform::Source.current)
    Platform::Record.writing do
      [
        upsert(Platform::Client, source.clients, source.name),
        upsert(Platform::User, source.users, source.name),
        upsert(Platform::Project, source.projects, source.name),
        upsert(Platform::Document, source.documents, source.name),
        upsert(Platform::Meeting, source.meetings, source.name)
      ].reduce { |a, b| combine(a, b) }
    end
  end

  def upsert(model, records, source_name)
    created = 0
    updated = 0
    seen = []

    records.each do |attributes|
      attributes = resolve_references(model, attributes)
      row = model.find_or_initialize_by(platform_id: attributes[:platform_id])

      if row.new_record?
        row.assign_attributes(attributes)
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
               missing: mark_missing(model, seen))
  end

  # Lo que ya no viene del origen se MARCA, no se borra. Es el invariante 1 por
  # su lado menos obvio: una cita ya emitida tiene que seguir resolviendo dentro
  # de un artefacto que nadie puede reescribir, y para eso la fila tiene que
  # seguir existiendo aunque el documento haya desaparecido de platform.
  #
  # Estaba escrito en el comentario de esta clase desde F2 y no estaba hecho: el
  # informe devolvía siempre `missing: 0`.
  def mark_missing(model, seen)
    gone = model.where.not(platform_id: seen).where(missing_since: nil)

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
