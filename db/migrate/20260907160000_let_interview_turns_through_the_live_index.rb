# El índice de «una sola ejecución viva» deja pasar los turnos (F11 · B9).
#
# `idx_agent_runs_one_live` es único parcial sobre
# `(initiative_id, agent, purpose, iteration)` para las filas `queued` y
# `running`. Existe porque la interfaz, un relanzamiento manual y el reintento de
# un job pueden solaparse, y pagar dos veces por el mismo trabajo es exactamente
# lo que no puede pasar.
#
# El turno de conversación del ARQUITECTO es otra cosa, y por dos razones:
#
# **1 · Dos turnos simultáneos no son un error.** Son dos preguntas de la misma
# persona, y las dos valen. No hay trabajo duplicado que evitar: cada turno lleva
# su propio mensaje y produce sus propias decisiones.
#
# **2 · Y sobre todo: un turno corre DENTRO de la petición HTTP.** Los seis
# agentes de siempre son un job de Sidekiq, que si muere deja su reintento y su
# rastro. Una petición que muera por timeout de Puma no ejecuta ningún `ensure`:
# la fila se quedaría en `running` para siempre y el índice **bloquearía todos
# los turnos siguientes de ese evolutivo**, sin forma de desatascarlo desde la
# pantalla. Un candado pensado para proteger de un gasto doble se convertiría en
# la avería.
#
# ⚠ EL `7` ES EL ENTERO DE `interview`, escrito a mano porque una cláusula
# `WHERE` de Postgres no puede leer un enum de Ruby. Es la misma familia de
# trampa que los enums posicionales de `agent` y `kind`: si alguien reordenara
# `AgentRun#purpose`, este índice pasaría a excluir otro propósito en silencio.
# Por eso `agent_run_test` fija que `interview` sigue siendo el 7 y comprueba lo
# que el índice hace, no lo que dice.
class LetInterviewTurnsThroughTheLiveIndex < ActiveRecord::Migration[8.1]
  NAME = "idx_agent_runs_one_live".freeze
  COLUMNS = %i[initiative_id agent purpose iteration].freeze

  INTERVIEW = 7

  def up
    remove_index :agent_runs, name: NAME
    add_index :agent_runs, COLUMNS, unique: true, name: NAME,
              where: "status IN (0, 1) AND purpose <> #{INTERVIEW}"
  end

  def down
    remove_index :agent_runs, name: NAME
    add_index :agent_runs, COLUMNS, unique: true, name: NAME,
              where: "status IN (0, 1)"
  end
end
