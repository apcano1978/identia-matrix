# frozen_string_literal: true

require "test_helper"

# ANCLAR SOLO SE HACE EN UN SITIO, y aquí se comprueba.
#
# `initiative_repositories.pinned_sha` es la columna más irreversible del
# sistema después de una clave de artefacto: dentro de cada cita de código va un
# `@<sha7>` que sale de ahí, y esas citas viven en markdown que nadie puede
# reescribir. Moverlo no rompe nada visiblemente — deja las citas apuntando a
# otro sitio y afirmando lo mismo.
#
# `Repositories::Index#pin` lo escribe **una sola vez** y respeta el que ya
# esté. Esa garantía vale mientras nadie más escriba la columna, y B6 añadió un
# servicio vecino —`Repositories::Probe`, que lee un repositorio al registrarlo—
# que está a un paso de hacerlo «ya que estamos». Este test es lo que hace que
# ese paso se note.
#
# No comprueba el comportamiento: comprueba la FORMA. Es la misma disciplina que
# `el_almacen_de_artefactos_es_solo_de_artefactos_test` y que el invariante de
# que matrix no ejecuta código ajeno.
class SoloIndexAnclaTest < ActiveSupport::TestCase
  ANCLA = Rails.root.join("app/services/repositories/index.rb")

  test "solo Repositories::Index escribe pinned_sha" do
    escritores = Rails.root.glob("app/**/*.rb").reject { |path| path == ANCLA }.select do |path|
      # `pinned_sha:` con dos puntos es una asignación —en un `update!`, un
      # `create!` o un `new`—. Leerla es `link.pinned_sha`, sin ellos, y eso lo
      # hacen media docena de sitios con todo el derecho.
      sin_comentarios(path).match?(/pinned_sha:/)
    end

    assert_empty escritores.map { |path| path.relative_path_from(Rails.root).to_s },
                 "alguien más escribe el anclaje. Es la columna que va dentro de " \
                 "cada cita de código ya emitida: si de verdad hace falta moverlo, " \
                 "que sea una decisión discutida y no un `update!` de paso"
  end

  # Y la otra mitad: que el que sí lo escribe lo siga escribiendo una sola vez.
  # Sin esto, el test de arriba se cumpliría igual con un `pin` que reescribiera
  # el anclaje en cada indexación.
  test "y lo escribe solo cuando está en blanco" do
    assert_match(/if link\.pinned_sha\.blank\?/, ANCLA.read,
                 "el anclaje dejó de ser de una sola vez")
  end

  private
    def sin_comentarios(path) = path.read.gsub(/^\s*#.*$/, "")
end
