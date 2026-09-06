# frozen_string_literal: true

module Citations
  # Ata una cita ya parseada a su FUENTE. Solo lectura: no escribe nada, no
  # levanta nada, y devuelve `nil` cuando no hay contra qué resolver.
  #
  # Dos reglas gobiernan este servicio, y las dos son invariantes:
  #
  # INVARIANTE 4 — una cita resuelve SIEMPRE contra la fuente, nunca contra un
  # índice. El día que el índice se rehaga en brain, ninguna cita ya emitida se
  # rompe: el índice es derivado y desechable, la cita no.
  #
  # INVARIANTE 10 — la resolución está acotada al PROYECTO. Entra por la FIRMA,
  # no por el cuerpo: quien llama tiene que decir de qué proyecto habla, y así no
  # hay forma de olvidarse de la frontera. Una cita que apunta a material de otro
  # proyecto devuelve `nil` y se marca; no es un filtro de presentación.
  #
  # ── La frontera se mudó en F11, y quedó ASIMÉTRICA a propósito ─────────────
  #
  # Tres de las cinco consultas filtran por `project_id` —repositorio, nota y
  # artefacto— porque son tablas nativas de matrix y el proyecto es su raíz.
  #
  # Las otras dos —documento y reunión— **siguen filtrando por
  # `platform_client_id`**, y eso NO es un resto por limpiar. Son la proyección
  # de solo lectura de platform: llegan sin ninguna noción de proyecto de matrix,
  # y un documento puede alimentar legítimamente a dos proyectos del mismo
  # cliente. Eso no es «material de otro proyecto»: es material del cliente, y su
  # acotado por evolutivo lo hace `initiative_sources`, no una clave foránea.
  #
  # La frontera nueva es MÁS ESTRECHA que la vieja: dos clientes no comparten
  # proyecto, así que todo lo que era legal lo sigue siendo, y además un proyecto
  # deja de ver el material de otro proyecto del mismo cliente. Eso es lo que
  # hizo segura la migración.
  #
  # En un proyecto PROPIO, `[src:doc/…]` y `[src:meet/…]` devuelven `nil`: no hay
  # cliente detrás y por tanto no hay proyección. No es un hueco — es que matrix
  # no acepta documentos propios hasta F12.
  #
  # Ninguna consulta navega asociaciones para llegar a la frontera: es la misma
  # disciplina que exige
  # test/invariants/no_agent_crosses_the_project_boundary_test.rb.
  class Resolve
    class << self
      # reference — un Citations::Reference (el objeto de valor de F0)
      # project   — un Project. EL OBJETO, no el id: documento y reunión
      #             necesitan su `platform_client_id`, y con un id habría que
      #             cargarlo en cada cita — `Attach` resuelve muchas de golpe.
      def call(reference, project:)
        return nil if reference.blank? || project.blank?

        case reference.kind
        when "code", "verify" then repository(reference, project)
        when "doc"            then document(reference, project)
        when "meet"           then meeting(reference, project)
        when "note"           then note(reference, project)
        when *Grammar::ARTIFACT_KINDS then artifact(reference, project)
        end
      end

      # El repositorio que califica una cita de código. Es lo que va a la
      # columna `citations.repository_id`, que es la que sostiene el invariante
      # 4 con una validación —y por eso una cita de código acaba con dos
      # vínculos al mismo repositorio, `repository_id` y `target`. Es
      # redundante a propósito: son dos preguntas distintas —«¿de qué
      # repositorio habla?» y «¿contra qué resuelve?»— que en `code` coinciden.
      # No se «limpia» ninguno de los dos.
      def repository_for(reference, project:)
        return nil unless Grammar.repository_qualified?(reference&.kind)

        repository(reference, project)
      end

      private
        # El cliente del proyecto, para las dos consultas que siguen siendo
        # suyas. Un proyecto propio no tiene, y entonces no hay nada que
        # resolver.
        def client_id_of(project) = project.platform_client_id

        def repository(reference, project)
          return nil if reference.repository.blank?

          Repository.find_by(project_id: project.id,
                             name: reference.repository)
        end

        # El slug del documento es propiedad de matrix y está congelado desde la
        # primera sincronización: aunque en platform renombren el documento, la
        # cita que lo nombra sigue resolviendo.
        def document(reference, project)
          client_id = client_id_of(project)
          return nil if client_id.blank?

          Platform::Document.find_by(platform_client_id: client_id,
                                     slug: reference.locator)
        end

        # El locator de una reunión es la FECHA. El sufijo —la enmienda aditiva
        # de la gramática— solo desempata cuando ese día hubo más de una: sin él
        # habría que elegir por orden de inserción, que es elegir al azar.
        def meeting(reference, project)
          client_id = client_id_of(project)
          return nil if client_id.blank?

          held_on = Date.parse(reference.locator)
          scope = Platform::Meeting.where(platform_client_id: client_id,
                                          held_on: held_on)

          return scope.find_by(slug: reference.meeting_slug) if reference.meeting_slug.present?

          scope.order(:platform_id).first
        rescue Date::Error
          nil
        end

        # El locator de una nota es la FECHA y el autor viaja aparte, igual que
        # el sufijo de una reunión: `[src:note/2026-05-08-ap]` tiene locator
        # `2026-05-08` y autor `ap`. El código de la nota los junta. Buscar por
        # el locator a secas —que es lo que hacía el resolvedor del seed— no
        # encuentra nunca nada; no se veía porque el seed no siembra notas.
        # Con autor, el código se compone y se busca EXACTO —incluido el ordinal
        # de P8, si lo trae—. Sin autor no hay más remedio que el LIKE, y ahí
        # está el porqué de que el ordinal vaya anidado dentro del autor: si
        # fuera un sufijo suelto, `note/2026-08-17-antonio` parsearía sin autor
        # y esta rama devolvería la primera nota de ese día, en silencio, dentro
        # de un artefacto que nadie puede reescribir. Anidado, esa cita no
        # parsea y no llega hasta aquí.
        def note(reference, project)
          scope = HumanNote.where(project_id: project.id)

          return scope.find_by(code: code_for(reference)) if reference.author.present?

          scope.where("code LIKE ?", "#{reference.locator}-%").order(:id).first
        end

        def code_for(reference)
          [ reference.locator, reference.author, reference.note_slug ].compact.join("-")
        end

        # Una cita derivada apunta a un artefacto por su `code`, que no lleva
        # versión: resuelve contra la última publicada. Corregir un artefacto es
        # publicar la siguiente versión, así que la última es la vigente.
        def artifact(reference, project)
          Artifact.where(project_id: project.id,
                         code: reference.locator).latest_first.first
        end
    end
  end
end
