# La credencial con la que matrix LEE los repositorios de un cliente (F8 §B.2).
#
# Es la primera vez que matrix guarda una credencial de acceso a algo de un
# cliente, y va cifrada con Active Record Encryption — que está configurada
# desde F0 anticipando justo esto.
#
# **Por cliente y de solo lectura.** Es la frontera de cliente aplicada al
# acceso y no solo a los datos: nunca una credencial compartida entre clientes,
# y nunca una con permiso de escritura — el único que escribe en un repositorio
# es Claude Code tras GATE 1, y esa es otra cadena.
#
# **Sin `revoked_at` y sin `update`.** Rotar es emitir otra: manda la más
# reciente y las anteriores quedan como rastro. Matrix no tiene un solo
# `update`, y esta tabla no lo estrena — es la misma forma que tiene todo lo
# demás que escribe, un acto que ocurre una vez y deja constancia.
class CreateRepositoryCredentials < ActiveRecord::Migration[8.0]
  def change
    create_table :repository_credentials do |t|
      t.references :platform_client, null: false, foreign_key: true
      t.string :host, null: false
      t.text   :token, null: false
      t.string :note

      t.timestamps
    end

    add_index :repository_credentials, [ :platform_client_id, :host, :created_at ],
              name: "idx_repository_credentials_latest"
  end
end
