# frozen_string_literal: true

module Artifacts
  # El único camino por el que un artefacto llega al bucket.
  #
  # Hace cuatro cosas y **el orden entre ellas no es indiferente**:
  #
  #   1. Calcula el checksum del CUERPO, antes de anteponer nada.
  #   2. Compone el front-matter y lo antepone.
  #   3. Sube los bytes.
  #   4. Registra la fila apuntando al blob ya subido.
  #
  # Subir antes de registrar, y no al revés. Si falla la subida no queda fila: el
  # artefacto simplemente no se publicó y se reintenta. Si se registrara primero
  # y fallara la subida quedaría una fila apuntando a nada — y una clave
  # inmutable reservada para un contenido que no existe es mucho peor que un blob
  # huérfano, que se purga sin consecuencias.
  #
  # ── Por qué la transacción no envuelve la subida ─────────────────────────
  #
  # Envolverla sería peor por dos razones. Mantendría abierta una transacción de
  # Postgres durante un PUT a S3, que puede tardar segundos. Y el rollback **no
  # borraría el objeto de todos modos**: matrix no tiene `DeleteObject`, y esa es
  # justamente la propiedad que esta fase existe para construir.
  #
  # La garantía «no hay fila sin bytes» la da EL ORDEN, no el rollback. Lo que la
  # transacción sí garantiza es más pequeño y más real: la fila, su adjunto y sus
  # citas aterrizan juntos, o no aterriza ninguno.
  class Publish
    # Reescribir una clave ya publicada. Se levanta explícitamente para que el
    # llamante vea qué clave y por qué, en vez de un choque de índice único.
    class AlreadyPublished < StandardError; end

    Result = Data.define(:artifact, :key, :checksum, :document)

    class << self
      # Dos argumentos son obligatorios y podrían no parecerlo:
      #
      # `produced_at` va SIN DEFAULT a propósito. Con `Time.current` el seed
      # produciría bytes distintos en cada resiembra para la misma clave, y
      # cualquier test que compare documentos se volvería intermitente.
      #
      # `produced_by_run` porque `produced_by` es un campo REQUERIDO del
      # front-matter congelado en F0: todo artefacto lo produce una ejecución de
      # un agente, y un artefacto sin quién lo produjo no es trazable.
      def call(initiative:, kind:, body:, produced_at:, produced_by_run:,
               derives_from: nil, version: nil, round: nil, number: nil)
        client = initiative.platform_client
        code = Key.code(kind: kind, round: round,
                        number: number || Key.number_from_initiative(initiative.code))
        version ||= next_version_for(initiative, code)
        key = Key.build(client: client.slug, initiative: initiative.code,
                        code: code, version: version)

        refuse_republication!(key)

        # 1 · El checksum es del CUERPO, no del fichero: el front-matter contiene
        #     el checksum, así que no puede calcularse sobre sí mismo.
        checksum = FrontMatter.checksum_for(body)

        # 2 · La cabecera que viaja con el fichero. Quien saque un artefacto del
        #     bucket tiene que poder saber qué es sin consultar a matrix.
        attributes = FrontMatter.build(
          key: key, kind: kind, code: code, version: version,
          initiative: initiative.code, client: client.slug,
          produced_by: produced_by_run&.code, produced_at: produced_at,
          derives_from: storage_key_of(derives_from), checksum: checksum)
        document = FrontMatter.render(attributes, body)

        # 3 · Los bytes, fuera de la transacción.
        blob = upload(document, version)

        # 4 · La fila, su adjunto y sus citas.
        artifact = register(initiative: initiative, kind: kind, code: code,
                            version: version, key: key, checksum: checksum,
                            attributes: attributes, blob: blob,
                            produced_by_run: produced_by_run, body: body)

        Result.new(artifact: artifact, key: key, checksum: checksum,
                   document: document)
      end

      private
        def next_version_for(initiative, code)
          initiative.artifacts.where(code: code).maximum(:version).to_i + 1
        end

        def refuse_republication!(key)
          return unless Artifact.exists?(storage_key: key)

          raise AlreadyPublished,
                "#{key} ya está publicado: corregir un artefacto es publicar " \
                "la versión siguiente, no reescribir ésta"
        end

        def storage_key_of(derives_from)
          derives_from.is_a?(Artifact) ? derives_from.storage_key : derives_from
        end

        def upload(document, version)
          ActiveStorage::Blob.create_and_upload!(
            io: StringIO.new(document), filename: "v#{version}.md",
            content_type: "text/markdown")
        end

        def register(initiative:, kind:, code:, version:, key:, checksum:,
                     attributes:, blob:, produced_by_run:, body:)
          ApplicationRecord.transaction do
            artifact = Artifact.create!(
              initiative: initiative, platform_client: initiative.platform_client,
              kind: kind, code: code, version: version, storage_key: key,
              checksum: checksum, front_matter: attributes,
              produced_by_run: produced_by_run)

            # En dos pasos y no `create!(body: blob)`: `refuse_column_changes`
            # deja pasar el guardado que solo adjunta bytes por primera vez.
            artifact.body.attach(blob)

            # Las citas salen del CUERPO, no del documento. El front-matter no
            # lleva ninguna —la gramática exige corchetes— pero pasarle el
            # documento haría que un cambio futuro de la cabecera pudiera
            # inventar citas en silencio.
            Citations::Attach.body(citable: artifact, body: body,
                                   client: initiative.platform_client_id)

            artifact
          end
        rescue ActiveRecord::RecordNotUnique => error
          # Dos publicaciones simultáneas del mismo código calculan la misma
          # versión. El índice único las separa; la segunda deja un blob
          # huérfano, que es purgable.
          raise AlreadyPublished, "#{key} se publicó a la vez desde otro sitio: #{error.message}"
        end
    end
  end
end
