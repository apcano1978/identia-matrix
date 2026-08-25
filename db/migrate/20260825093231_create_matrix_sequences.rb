# El contador de los códigos que matrix asigna: `ev-042`, y en F9 `pkg-046`.
#
# Una TABLA y no un `max(code) + 1`, y la razón no es la concurrencia —que
# también— sino que **un número de evolutivo no se recicla nunca**. `ev-031`
# está dentro de claves de artefacto inmutables y de citas ya emitidas; el día
# que se borre una fila, un `max` volvería a repartir su número y el evolutivo
# nuevo heredaría las citas del viejo.
#
# El contador sobrevive a las filas. Esa es toda la diferencia, y es la que
# importa.
class CreateMatrixSequences < ActiveRecord::Migration[8.0]
  def change
    create_table :matrix_sequences do |t|
      t.string  :name, null: false, index: { unique: true }
      t.integer :last_number, null: false, default: 0

      t.timestamps
    end
  end
end
