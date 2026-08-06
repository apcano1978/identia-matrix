# El párrafo que explica QUÉ SE DECIDIÓ en un repositorio, por evolutivo.
#
# Es el producto entero en una línea: lo que hace que el tercer evolutivo sobre
# un repositorio arranque sabiendo lo que decidieron los dos anteriores. La ficha
# de repositorio lo lee y TANK lo leerá en F9.
#
# Va en la CELDA (evolutivo × repositorio) y no en el evolutivo: un evolutivo que
# toca tres repositorios decide cosas distintas en cada uno. En F9 lo escribirá
# LINK al cerrar; hasta entonces lo siembra el catálogo de la maqueta.
class AddDecisionNoteToInitiativeRepositories < ActiveRecord::Migration[8.0]
  def change
    add_column :initiative_repositories, :decision_note, :text
  end
end
