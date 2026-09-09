# Cuándo se decidió el ámbito documental de un evolutivo (F12 · B5).
#
# ── Por qué una fecha y no el conteo de filas ──────────────────────────────
#
# Hasta aquí, «qué puede leer un agente» se deducía de si `initiative_sources`
# tenía filas: con filas, esas; sin filas, todo lo disponible —«la ausencia de
# fila ES la herencia»—. Se sostenía porque **nadie podía crear filas desde la
# aplicación**: solo las sembraba el seed, así que un evolutivo tenía las nueve
# de la maqueta o ninguna.
#
# B5 trae la pantalla, y con ella dos cosas que el conteo no sabe decir:
#
#   - Marcar UNA fuente apagaba la herencia de TODAS (P25). Una reunión marcada
#     dejaba al agente sin un solo documento, y nada lo avisaba.
#   - «Ninguna fuente» era inexpresable. Cero filas volvía a significar «todas»,
#     así que el «arrancar solo con conversación» que ofrece el rediseño no se
#     podía representar.
#
# Con la fecha, las dos desaparecen: **decidir el ámbito es un acto**, y esta
# columna dice cuándo ocurrió.
#
#   NULL      →  nadie lo ha recortado: entra todo lo disponible, y también lo
#                que se suba mañana
#   con fecha →  las filas SON el ámbito, y cero filas son cero fuentes
#
# ── El relleno hacia atrás no es opcional ──────────────────────────────────
#
# `ev-031` tiene sus nueve filas sembradas y ninguna fecha. Sin este `UPDATE`
# pasaría de mandar siete fuentes a mandar todas las de vivla, **en silencio y
# con la suite en verde**: el evolutivo que sí llama a un agente de verdad es
# justo el que se rompería. La regla del relleno es la que preserva el
# comportamiento: quien ya tenía filas, ya tenía ámbito.
class AddSourcesScopedAtToInitiatives < ActiveRecord::Migration[8.1]
  def up
    add_column :initiatives, :sources_scoped_at, :datetime

    # `opened_at` y no `NOW()`: la fecha dice cuándo se decidió, y de lo ya
    # sembrado lo único cierto es que se decidió al abrirlo.
    execute <<~SQL.squish
      UPDATE initiatives SET sources_scoped_at = opened_at
      WHERE EXISTS (SELECT 1 FROM initiative_sources
                    WHERE initiative_sources.initiative_id = initiatives.id)
    SQL
  end

  def down
    remove_column :initiatives, :sources_scoped_at
  end
end
