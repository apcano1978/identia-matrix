# Admitir en matrix a un cliente que todavía no tiene proyecto (F8, §clientes).
#
# `Platform::HttpSource#clients` solo proyecta los leads CON TRABAJO EN MARCHA, y
# ese filtro es correcto: matrix es lo contrario de un CRM y sin él se llenó de
# nueve clientes teniendo trabajo en dos. Pero tiene un reverso que nadie buscó
# —el mismo que P14 por su otro lado—: mientras el proyecto no existe, el cliente
# no llega a matrix, así que no hay dónde reunir su documentación justo en el
# momento en que se está preparando el trabajo.
#
# **La excepción se nombra, no se ensancha el criterio.** Una fila por cliente
# admitido, con el motivo escrito. Ampliar el filtro habría devuelto el embudo
# comercial entero; esto deja entrar a uno y deja constancia de por qué.
#
# `platform_id` y NO `platform_client_id`: cuando se admite a alguien todavía no
# existe su fila en la proyección —admitirlo es justo lo que hará que exista—,
# así que no hay clave foránea a la que apuntar. Es el id del lead en platform,
# que es lo único estable entre los dos sistemas.
#
# **Sin `revoked_at` y sin `update`**, como las credenciales: retirar una
# admisión es borrar su fila, y entonces el cliente cae del catálogo y
# `Projection#mark_missing` lo marca como ausente en vez de borrarlo — que es lo
# que hay que hacer si para entonces ya tenía citas emitidas.
class CreateClientAdmissions < ActiveRecord::Migration[8.0]
  def change
    create_table :client_admissions do |t|
      t.bigint :platform_id, null: false
      t.string :reason, null: false
      t.string :admitted_by, null: false

      t.timestamps
    end

    add_index :client_admissions, :platform_id, unique: true
  end
end
