# frozen_string_literal: true

module Sources
  # Qué puede leer un agente para un evolutivo, y por qué.
  #
  # El concepto entero cabe en una frase: **el ámbito es un FILTRO, nunca una
  # copia**. `initiative_sources` marca lo que se le acota explícitamente a un
  # evolutivo; su AUSENCIA significa «todo lo disponible». Un documento vive una
  # sola vez y aparece en tantos evolutivos como haga falta sin duplicarse en
  # ninguno.
  #
  # Las consultas parten de la CLAVE FORÁNEA —`platform_client_id` o
  # `project_id`— y no de asociaciones: esta pantalla existe precisamente para
  # hacer inspeccionable esa frontera, y sería raro que fuera el único sitio que
  # la cruza.
  #
  # ── Los tres orígenes, y lo que sale de juntarlos ─────────────────────────
  #
  #   scoped         lo acotado explícitamente a este evolutivo
  #   own            los documentos SUBIDOS a este proyecto, sin acotar   (F12)
  #   inherited      lo del CLIENTE que no esté acotado
  #
  #   available_for  todo lo que podría entrar en un PROYECTO — sin evolutivo
  #   in_scope       lo que de verdad entra: una de las dos ramas, según la
  #                  fecha de `initiatives.sources_scoped_at`
  #
  # `inherited` sigue siendo del cliente, no del proyecto, y no es un resto por
  # limpiar: `Platform::Document` y `Platform::Meeting` son la proyección de
  # platform y llegan sin noción de proyecto. `own` es lo contrario —nace dentro
  # del proyecto— y por eso es una consulta aparte y no una rama de la otra.
  #
  # Un proyecto propio no hereda nada de nadie; desde F12 eso ya no lo deja sin
  # fuentes, que era el hueco que abrió F11.
  class Scope
    Group = Data.define(:sources, :refs) do
      def size = sources.size
      def refs_for(source) = refs[source] || 0
      # Los documentos subidos no se sincronizan con nada: no vienen de fuera.
      # `try` en vez de una comprobación de clase porque lo que importa aquí es
      # si hay sincronización que contar, no de qué tabla salió cada fila.
      def synced_at = sources.filter_map { |source| source.try(:synced_at) }.max
    end

    class << self
      # Lo que se le acotó a este evolutivo, lo más referenciado primero.
      def scoped(initiative)
        rows = initiative.initiative_sources.includes(:source).most_referenced

        %i[documents meetings].index_with do |kind|
          group = rows.select { |row| types_for(kind).include?(row.source_type) }

          Group.new(sources: group.map(&:source),
                    refs: group.to_h { |row| [ row.source, row.refs_count ] })
        end
      end

      # Los documentos del PROYECTO que no estén acotados ni retirados.
      #
      # Retirar saca del ámbito por defecto, que es lo que retirar significa. No
      # saca de lo YA acotado —eso lo decide `scoped`, y un evolutivo en marcha
      # no pierde una fuente bajo los pies— ni de las citas ya emitidas, que
      # siguen resolviendo.
      #
      # No hay `meetings`: matrix no acepta transcripciones propias, y devolver
      # un grupo vacío sería insinuar que algún día se llenará por aquí.
      def own(initiative)
        taken = initiative.initiative_sources.pluck(:source_type, :source_id)

        { documents: rest(ProjectDocument, initiative, taken) }
      end

      # Todo lo demás del cliente. La ausencia ES la herencia: no hay una
      # segunda tabla, ni una copia, ni una marca que decir.
      def inherited(initiative)
        taken = initiative.initiative_sources.pluck(:source_type, :source_id)

        { documents: rest(Platform::Document, initiative, taken),
          meetings: rest(Platform::Meeting, initiative, taken) }
      end

      # ⚠ LO QUE DE VERDAD ENTRA EN ÁMBITO, que es lo que viaja al agente.
      #
      # **Lo acotado si alguien lo recortó; si no, todo lo disponible.** Es la
      # regla que el runbook enuncia —«la ausencia de decisión ES la herencia»—
      # y hasta B4 era verdad en la pantalla y mentira en el payload:
      # `Runtime::Request` mandaba solo lo acotado, así que un evolutivo recién
      # abierto salía con CERO fuentes mientras su pantalla enseñaba las del
      # cliente. No se notó porque el único evolutivo con agentes de verdad tiene
      # sus filas sembradas.
      #
      # ⚠ Y quien decide la rama es la FECHA, no el conteo de filas. B4 contaba
      # filas y B5 tuvo que dejar de hacerlo, porque contar no sabe decir dos
      # cosas que la pantalla nueva permite: que marcar una reunión apagaba la
      # herencia de todos los documentos (P25), y que «ninguna fuente» —el
      # «arrancar solo con conversación» del rediseño— volvía a leerse como
      # «todas». Con la fecha, cero filas SON cero fuentes.
      #
      # Vive aquí y no en `Runtime::Request` porque es el concepto de ámbito, no
      # un detalle de cómo se compone una petición: la pantalla y el agente
      # tienen que responder lo mismo o la pantalla miente.
      #
      # Devuelve el mismo `{ kind => Group }` que los otros tres, para que quien
      # llama no tenga que saber por cuál de las dos ramas salió.
      def in_scope(initiative)
        return scoped(initiative) if initiative.sources_scoped?

        available_for(initiative.project)
      end

      # TODO lo que podría entrar en un proyecto, sin evolutivo por medio.
      #
      # Existe porque el alta necesita pintar las casillas **antes** de que el
      # evolutivo exista, y porque es la lista LEGAL contra la que
      # `Initiatives::Open` comprueba lo que llega del formulario: de aquí no se
      # sale, y así el invariante 10 no depende de que la vista pinte bien.
      #
      # Los propios PRIMERO: es lo más cercano al proyecto, y es el orden en que
      # la pantalla los enseña.
      def available_for(project)
        { documents: Group.new(
            sources: available(ProjectDocument, project).to_a +
                     available(Platform::Document, project).to_a,
            refs: {}),
          meetings: Group.new(sources: available(Platform::Meeting, project).to_a,
                              refs: {}) }
      end

      # LO QUE EL FORMULARIO OFRECE MARCADO DE FÁBRICA: lo citable de lo
      # disponible.
      #
      # Vive aquí porque lo miran los DOS sitios que escriben el ámbito —el alta
      # y la pantalla de fuentes— para decidir lo mismo: si lo marcado coincide
      # con esto, nadie recortó. Dos copias de ese criterio serían dos criterios,
      # y la pantalla acabaría prometiendo un ámbito distinto del que se guarda.
      #
      # `plus:` es lo que ya está acotado y podría no estar disponible: un
      # documento acotado y luego retirado sigue en el ámbito de ese evolutivo,
      # y quien lo edite tiene que poder conservarlo.
      def offered(project, plus: [])
        (available_for(project).values.flat_map(&:sources) + plus)
          .uniq.select(&:citable?)
      end

      # ⚠ ¿RECORTÓ? **Sí cuando alguna de las ofrecidas se quedó sin marcar.**
      #
      # Es una RESTA y no una igualdad, y la diferencia se pagó descubriéndola:
      # con `Set == Set`, marcar todo lo que la pantalla enseña —incluido lo que
      # no tiene cuerpo— no desacotaba, porque lo ofrecido solo cuenta lo
      # citable. La pantalla decía «márcalo todo para volver a heredarlo todo» y
      # marcarlo todo no lo hacía.
      #
      # Con la resta, recortar significa lo que significa en la cabeza de quien
      # lo hace: **quitar algo que podía entrar**. Añadir de más una fuente sin
      # cuerpo no recorta nada —no viajaría igual, `Runtime::Request` la filtra—
      # así que no cambia el resultado, y no tiene por qué congelar el ámbito.
      def narrowed?(chosen, offered) = (offered - chosen).any?

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
        # Un documento es un documento venga de donde venga: los dos tipos caen
        # en el mismo grupo, y la pantalla los cuenta juntos.
        def types_for(kind)
          kind == :documents ? InitiativeSource::DOCUMENT_TYPES : [ "Platform::Meeting" ]
        end

        # Lo de un modelo que este evolutivo no tiene ya acotado.
        #
        # La frontera se elige por modelo: `ProjectDocument` es nativo de matrix
        # y filtra por `project_id`; los dos de platform son proyección y filtran
        # por `platform_client_id`, que en un proyecto propio es `nil` y por eso
        # no devuelven nada.
        def rest(model, initiative, taken)
          ids = taken.select { |type, _| type == model.name }.map(&:last)

          scope = available(model, initiative.project)
          scope = scope.where.not(id: ids) if ids.any?

          Group.new(sources: scope.to_a, refs: {})
        end

        def available(model, project)
          if model == ProjectDocument
            model.available.where(project_id: project&.id).order(:slug)
          else
            model.where(platform_client_id: project&.platform_client_id)
                 .order(:platform_id)
          end
        end
    end
  end
end
