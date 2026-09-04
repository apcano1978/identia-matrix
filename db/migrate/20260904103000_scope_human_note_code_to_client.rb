# La unicidad del código de una nota humana se acota al CLIENTE (P8).
#
# `code` era único en todo el sistema, y la gramática solo admitía
# `note/<fecha>[-<autor>]`: de ahí que solo cupiera una nota citable por autor y
# día. Lo que de verdad pasaba era peor que «la segunda no es citable» —que es
# como estuvo escrito el pendiente hasta el 26 de agosto—: la segunda daba un
# **500**. `HumanNote` validaba la unicidad y ningún llamante rescataba el
# `RecordInvalid`, así que la acción no se completaba.
#
# Y la colisión era GLOBAL, no por evolutivo. Rechazar la firma de GATE 1 en
# ev-014 por la mañana y autorizar una exención en ev-031 por la tarde reventaba
# aunque fueran de clientes distintos. Con un solo operador eso no es un caso
# raro.
#
# El ámbito correcto es el cliente, y no por comodidad: `Citations::Resolve#note`
# ya busca dentro de `platform_client_id`, así que una cita solo tiene que ser
# inequívoca dentro de su cliente — el invariante 10 impide que cruce esa
# frontera. El ámbito global era más estricto de lo necesario y no compraba nada.
#
# La otra mitad de P8 —el sufijo ordinal anidado tras el autor— va en
# `Citations::Grammar`, y es la tercera y última enmienda aditiva de la
# gramática: F9 cierra la ventana.
class ScopeHumanNoteCodeToClient < ActiveRecord::Migration[8.0]
  def change
    remove_index :human_notes, :code, unique: true
    add_index :human_notes, [ :platform_client_id, :code ], unique: true
  end
end
