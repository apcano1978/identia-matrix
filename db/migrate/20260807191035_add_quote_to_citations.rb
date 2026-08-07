# La frase concreta que una cita afirma estar citando.
#
# El ancla (`citations.fragment`) selecciona un PÁRRAFO —`#p2`—, no una frase, y
# el panel de procedencia tiene que resaltar lo citado dentro de ese párrafo.
# Sin esta columna el resaltado habría que inventarlo por heurística, que es
# fabricar un dato: cuando acertara no se sabría por qué, y cuando fallara
# marcaría lo que no era.
#
# La escribe QUIEN EMITE la cita, que es quien lo sabe: en F4 la siembra el
# seed, y desde F9 la trae el contrato con brain. Nullable a propósito — una
# cita sin frase declarada enseña el párrafo entero, sin marca.
class AddQuoteToCitations < ActiveRecord::Migration[8.0]
  def change
    add_column :citations, :quote, :string
  end
end
