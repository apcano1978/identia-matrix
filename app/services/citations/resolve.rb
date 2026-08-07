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
  # INVARIANTE 10 — la resolución está acotada al cliente. El cliente entra por
  # la FIRMA, no por el cuerpo: quien llama tiene que decir de quién habla, y
  # así no hay forma de olvidarse de la frontera. Una cita que apunta a material
  # de otro cliente devuelve `nil` y se marca; no es un filtro de presentación.
  #
  # Todas las consultas llevan `platform_client_id` en el `where` y ninguna
  # navega asociaciones para llegar al cliente: es la misma disciplina que exige
  # test/invariants/no_agent_crosses_the_client_boundary_test.rb.
  class Resolve
    class << self
      # reference — un Citations::Reference (el objeto de valor de F0)
      # client    — un Platform::Client o su id
      def call(reference, client:)
        return nil if reference.blank?

        client_id = client_id_for(client)
        return nil if client_id.blank?

        case reference.kind
        when "code", "verify" then repository(reference, client_id)
        when "doc"            then document(reference, client_id)
        when "meet"           then meeting(reference, client_id)
        when "note"           then note(reference, client_id)
        when *Grammar::ARTIFACT_KINDS then artifact(reference, client_id)
        end
      end

      # El repositorio que califica una cita de código. Es lo que va a la
      # columna `citations.repository_id`, que es la que sostiene el invariante
      # 4 con una validación —y por eso una cita de código acaba con dos
      # vínculos al mismo repositorio, `repository_id` y `target`. Es
      # redundante a propósito: son dos preguntas distintas —«¿de qué
      # repositorio habla?» y «¿contra qué resuelve?»— que en `code` coinciden.
      # No se «limpia» ninguno de los dos.
      def repository_for(reference, client:)
        return nil unless Grammar.repository_qualified?(reference&.kind)

        repository(reference, client_id_for(client))
      end

      private
        def client_id_for(client)
          client.is_a?(Platform::Client) ? client.id : client
        end

        def repository(reference, client_id)
          return nil if reference.repository.blank?

          Repository.find_by(platform_client_id: client_id,
                             name: reference.repository)
        end

        # El slug del documento es propiedad de matrix y está congelado desde la
        # primera sincronización: aunque en platform renombren el documento, la
        # cita que lo nombra sigue resolviendo.
        def document(reference, client_id)
          Platform::Document.find_by(platform_client_id: client_id,
                                     slug: reference.locator)
        end

        # El locator de una reunión es la FECHA. El sufijo —la enmienda aditiva
        # de la gramática— solo desempata cuando ese día hubo más de una: sin él
        # habría que elegir por orden de inserción, que es elegir al azar.
        def meeting(reference, client_id)
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
        def note(reference, client_id)
          scope = HumanNote.where(platform_client_id: client_id)

          return scope.find_by(code: "#{reference.locator}-#{reference.author}") if reference.author.present?

          scope.where("code LIKE ?", "#{reference.locator}-%").order(:id).first
        end

        # Una cita derivada apunta a un artefacto por su `code`, que no lleva
        # versión: resuelve contra la última publicada. Corregir un artefacto es
        # publicar la siguiente versión, así que la última es la vigente.
        def artifact(reference, client_id)
          Artifact.where(platform_client_id: client_id,
                         code: reference.locator).latest_first.first
        end
    end
  end
end
