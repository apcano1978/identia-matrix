# frozen_string_literal: true

module Artifacts
  # Reconcilia el registro de artefactos con lo que hay de verdad en el bucket.
  #
  # El checksum se guarda desde F2 y hasta F5 nadie lo había comprobado nunca
  # contra los bytes. Esto es lo que convierte «los artefactos son inmutables»
  # de una intención en algo que se puede auditar.
  #
  # Tres divergencias, y son PROBLEMAS DISTINTOS. Mezclarlas en un contador
  # único sería inútil: una es imposible, otra es basura y la tercera es grave.
  #
  #   fila sin objeto     se registró algo que no llegó al bucket. No debería
  #                       poder pasar desde que Publish sube antes de registrar
  #   objeto sin fila     blob huérfano de una publicación fallida. Purgable
  #   checksum distinto   alguien tocó el contenido. Es el hallazgo grave
  #
  # El camino de comprobación es el inverso del de publicación: descargar,
  # separar el front-matter, hashear el CUERPO y comparar.
  class Verify
    Divergence = Data.define(:kind, :key, :detail) do
      def to_s = "#{key} · #{detail}"
    end

    Report = Data.define(:checked, :missing_objects, :orphan_objects,
                         :checksum_mismatches) do
      def divergences = missing_objects + orphan_objects + checksum_mismatches

      def divergences? = divergences.any?

      def to_s
        "#{checked} artefactos comprobados · " \
          "#{missing_objects.size} sin objeto · " \
          "#{orphan_objects.size} huérfanos · " \
          "#{checksum_mismatches.size} con el checksum cambiado"
      end
    end

    def self.call(scope: Artifact.all) = new(scope: scope).call

    def initialize(scope:)
      @scope = scope
      @missing = []
      @mismatched = []
      @seen_blob_keys = []
    end

    def call
      checked = 0

      @scope.includes(body_attachment: :blob).find_each do |artifact|
        checked += 1
        check(artifact)
      end

      Report.new(checked: checked, missing_objects: @missing,
                 orphan_objects: orphans, checksum_mismatches: @mismatched)
    end

    private
      def check(artifact)
        unless artifact.body.attached?
          return @missing << Divergence.new(
            kind: :missing_object, key: artifact.storage_key,
            detail: "la fila no tiene bytes adjuntos")
        end

        @seen_blob_keys << artifact.body.blob.key

        document = read(artifact)
        return if document.nil?

        compare(artifact, document)
      end

      def read(artifact)
        artifact.document
      rescue ActiveStorage::FileNotFoundError, Errno::ENOENT
        @missing << Divergence.new(
          kind: :missing_object, key: artifact.storage_key,
          detail: "el objeto #{artifact.body.blob.key} no está en el almacén")
        nil
      end

      # Se comprueban los TRES sitios donde vive el checksum: la columna, la
      # cabecera incrustada en los bytes y el hash real del cuerpo. Los tres
      # tienen que decir lo mismo; cualquier discrepancia es el mismo hallazgo.
      def compare(artifact, document)
        attributes, body = FrontMatter.parse(document)
        actual = FrontMatter.checksum_for(body)

        return if actual == artifact.checksum &&
                  attributes[:checksum] == artifact.checksum

        @mismatched << Divergence.new(
          kind: :checksum_mismatch, key: artifact.storage_key,
          detail: "registrado #{artifact.checksum} · " \
                  "cabecera #{attributes[:checksum] || 'sin cabecera'} · " \
                  "real #{actual}")
      end

      # Un objeto que no cuelga de ningún artefacto. La pregunta solo se puede
      # contestar listando, y solo tiene sentido porque el bucket es PROPIO de
      # matrix: aquí no se guarda otra cosa, así que lo que no case es huérfano
      # por definición.
      def orphans
        (Artifacts::Store.keys - @seen_blob_keys).map do |key|
          Divergence.new(kind: :orphan_object, key: key,
                         detail: "en el almacén, sin fila que lo reclame")
        end
      end
  end
end
