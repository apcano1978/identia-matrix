# frozen_string_literal: true

module Citations
  # Las citas de código de un artefacto, agrupadas por repositorio.
  #
  # Es el bloque que justifica que el calificador de repositorio sea
  # obligatorio: sin él, `rates.ts#L40` y `api.ts#L64` serían dos ficheros
  # sueltos en ninguna parte.
  #
  # El COMMIT se enseña una vez por repositorio, no por cita: todas las citas de
  # código de un artefacto apuntan al commit fijado de ese repositorio en ese
  # momento. Si dos traen commits distintos es un ERROR y se enseña como tal —
  # promediarlo, o elegir uno, sería tapar que el artefacto afirma dos cosas
  # incompatibles sobre el mismo código.
  #
  # Esa regla vive aquí y no en la vista para poder probarla sin navegador.
  class CodeGroups
    Group = Data.define(:repository, :commits, :citations) do
      def name = repository&.name

      # El commit del grupo. Con divergencia no hay uno: la vista tiene que
      # enseñar los dos, y por eso esto devuelve nil en vez de escoger.
      def commit_sha = divergent? ? nil : commits.first

      def divergent? = commits.size > 1

      def size = citations.size
    end

    def self.call(citations)
      citations.select(&:kind_code?)
               .group_by(&:repository_id)
               .map { |_id, group| build(group) }
               .sort_by { |group| group.name.to_s }
    end

    def self.build(citations)
      ordered = citations.sort_by { |citation| [ citation.position || 0, citation.id.to_i ] }

      Group.new(repository: ordered.first.repository,
                commits: ordered.filter_map(&:commit_sha).uniq,
                citations: ordered)
    end
    private_class_method :build
  end
end
