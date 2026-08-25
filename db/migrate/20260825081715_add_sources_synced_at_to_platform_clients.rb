# Cuándo se miraron por última vez las FUENTES de un cliente (F8 §A.5).
#
# No es lo mismo que `synced_at`, y confundirlos hace mentir a la interfaz.
# `synced_at` lo pone `Platform::Projection` en cada fila que toca, y significa
# «esta fila se refrescó»: refrescar el catálogo de clientes lo actualiza en
# todos, aunque de ninguno se hayan pedido sus documentos.
#
# La pregunta que la ficha de un cliente tiene que poder contestar es la otra:
# «¿está al día lo de este cliente?». Con una sola columna, un cliente cuyos
# documentos llevan tres días sin mirarse diría que está al día cada vez que
# alguien descubre el catálogo — y un desfase invisible es exactamente lo que
# esta fase existe para evitar.
#
# Salió al escribir el test del ámbito, no al diseñar.
class AddSourcesSyncedAtToPlatformClients < ActiveRecord::Migration[8.0]
  def change
    add_column :platform_clients, :sources_synced_at, :datetime
  end
end
