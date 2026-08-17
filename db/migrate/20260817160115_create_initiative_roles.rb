# El papel de una persona EN UN EVOLUTIVO. No es su rol de acceso.
#
# `platform_users.role` dice si alguien puede entrar en matrix, y lo sincroniza
# identia-platform: meter ahí `approver` y `observer` —valores que platform no
# conoce— los borraría la primera sincronización de F8. Además son cosas
# distintas: el rol de acceso es de la persona, el papel es de la persona **en
# este trabajo concreto**, y la maqueta ya los llamaba así.
#
# `admin` y `superadmin` aprueban y firman en cualquier evolutivo sin necesidad
# de una fila aquí: son el equipo que opera el sistema. Esta tabla existe para
# lo otro — dar el papel a quien no es de ese equipo, y distinguir a quien solo
# puede levantar la mano de quien puede autorizar.
class CreateInitiativeRoles < ActiveRecord::Migration[8.0]
  def change
    create_table :initiative_roles do |t|
      t.references :initiative, null: false, foreign_key: true
      t.references :platform_user, null: false, foreign_key: true
      t.integer :role, null: false

      t.timestamps
    end

    # Un papel por persona y evolutivo: quien aprueba también puede levantar la
    # mano, así que dos filas para la misma persona no dirían nada nuevo.
    add_index :initiative_roles, %i[initiative_id platform_user_id],
              unique: true, name: "idx_initiative_roles_unique"
  end
end
