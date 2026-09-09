# frozen_string_literal: true

module Repositories
  # Leer un repositorio y anotar qué hay dentro —o por qué no se pudo (F12 · B6).
  #
  # Es lo que ocurre **al registrarlo**, cuando todavía no hay ningún evolutivo
  # que anclar. Tiene valor propio y no es un adelanto de la indexación: matrix
  # **no tiene ningún `update`**, así que un `remote_url` mal escrito no se
  # corrige — se registra otro repositorio—. Descubrirlo aquí, con el formulario
  # todavía a la vista, es la diferencia entre corregirlo en un minuto y
  # descubrirlo semanas después, cuando TANK escriba a ciegas.
  #
  # ⚠ **NO ANCLA NADA, y esa es la propiedad.** Lo único que escribe `pinned_sha`
  # en todo matrix sigue siendo `Repositories::Index#pin`, porque el anclaje es
  # irreversible: moverlo convertiría en mentira cada cita ya emitida contra él.
  # Que sean dos servicios y no uno con un `if` es lo que hace esa afirmación
  # comprobable, y hay un test estructural que la comprueba
  # —`test/architecture/solo_index_ancla_test.rb`—.
  #
  # Escribe lo que sí es suyo: `head_sha`, `files_count`, `last_synced_at` y el
  # motivo del fallo. Devuelve el repositorio, ya refrescado.
  class Probe
    def self.call(...) = new(...).call

    def initialize(repository:)
      @repository = repository
    end

    # `Unreachable` sale hacia arriba a propósito: es lo único que tiene sentido
    # reintentar, y quien decide cuántas veces es el job. Lo permanente —sin
    # origen legible, repositorio vacío— se anota y se acaba aquí: reintentarlo
    # daría el mismo resultado.
    def call
      source = Source.for(repository)
      return failed("sin origen legible") if source.nil?

      sha = source.head_sha
      return failed("el origen no devolvió commit") if sha.blank?

      indexed(sha, source.files_count(sha))
    rescue GithubSource::Error => error
      # Se anota ANTES de levantar: si los reintentos se agotan, el motivo ya
      # está en la fila y la pantalla lo cuenta sin esperar a nadie.
      failed("el origen no respondió · #{error.message}")
      raise Unreachable, error.message
    end

    private

    attr_reader :repository

    def indexed(sha, files)
      repository.update!(head_sha: sha, files_count: files,
                         last_synced_at: Time.current, indexing_error: nil)
      repository
    end

    def failed(reason)
      repository.update!(indexing_error: reason)
      repository
    end
  end
end
