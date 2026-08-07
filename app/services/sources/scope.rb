# frozen_string_literal: true

module Sources
  # Qué puede leer un agente para un evolutivo, y por qué.
  #
  # El concepto entero cabe en una frase: **el ámbito es un FILTRO, nunca una
  # copia**. `initiative_sources` marca lo que se le acota explícitamente a un
  # evolutivo; su AUSENCIA significa «heredada del cliente», que es lo visible
  # por defecto. Un documento vive una sola vez, en platform, y aparece en
  # tantos evolutivos como haga falta sin duplicarse en ninguno.
  #
  # Todas las consultas parten de `platform_client_id` y no de asociaciones:
  # esta pantalla existe precisamente para hacer inspeccionable esa frontera, y
  # sería raro que fuera el único sitio que la cruza.
  class Scope
    Group = Data.define(:sources, :refs) do
      def size = sources.size
      def refs_for(source) = refs[source] || 0
      def synced_at = sources.filter_map(&:synced_at).max
    end

    class << self
      # Lo que se le acotó a este evolutivo, lo más referenciado primero.
      def scoped(initiative)
        rows = initiative.initiative_sources.includes(:source).most_referenced

        %i[documents meetings].index_with do |kind|
          group = rows.select { |row| row.source_type == type_for(kind) }

          Group.new(sources: group.map(&:source),
                    refs: group.to_h { |row| [ row.source, row.refs_count ] })
        end
      end

      # Todo lo demás del cliente. La ausencia ES la herencia: no hay una
      # segunda tabla, ni una copia, ni una marca que decir.
      def inherited(initiative)
        taken = initiative.initiative_sources.pluck(:source_type, :source_id)

        { documents: rest(Platform::Document, initiative, taken),
          meetings: rest(Platform::Meeting, initiative, taken) }
      end

      # Para cada fuente en ámbito, los OTROS evolutivos que también la acotan.
      # Es lo que produce el «también en ev-014», y con ello lo que demuestra en
      # pantalla que el ámbito no es posesión.
      def shared(initiative)
        rows = initiative.initiative_sources.to_a
        return {} if rows.empty?

        InitiativeSource.includes(:initiative)
                        .where(source_type: rows.map(&:source_type),
                               source_id: rows.map(&:source_id))
                        .where.not(initiative_id: initiative.id)
                        .group_by { |row| [ row.source_type, row.source_id ] }
                        .transform_values { |group| group.map(&:initiative) }
      end

      def also_in(shared, source)
        shared[[ source.class.name, source.id ]] || []
      end

      private
        def type_for(kind)
          kind == :documents ? "Platform::Document" : "Platform::Meeting"
        end

        def rest(model, initiative, taken)
          ids = taken.select { |type, _| type == model.name }.map(&:last)

          scope = model.where(platform_client_id: initiative.platform_client_id)
          scope = scope.where.not(id: ids) if ids.any?

          Group.new(sources: scope.order(:platform_id).to_a, refs: {})
        end
    end
  end
end
