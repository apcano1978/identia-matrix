# frozen_string_literal: true

module ProjectDocuments
  # Varios ficheros de una vez, cada uno por su cuenta.
  #
  # **Uno rechazado no tira a los demás**, que es lo que hace utilizable arrastrar
  # una carpeta entera: subir cinco y que uno pase de 25 MB no puede dejar la
  # pantalla diciendo solo «error». Por eso devuelve las dos listas y no levanta.
  #
  # Vive fuera de los controladores porque desde F12 · B5 son dos los que suben:
  # la ficha del proyecto y el alta de un evolutivo, que acepta la documentación
  # de partida en el mismo formulario. Dos copias de esta regla serían dos reglas.
  class UploadAll
    Result = Data.define(:documents, :refusals) do
      def count = documents.size
      def any? = documents.any?
      def none? = documents.empty?
    end

    def self.call(project:, files:, uploader:)
      documents = []
      refusals = []

      Array(files).reject(&:blank?).each do |file|
        documents << Upload.call(project: project, file: file, uploader: uploader)
      rescue Upload::Refused => error
        refusals << error.message
      end

      Result.new(documents: documents, refusals: refusals)
    end
  end
end
