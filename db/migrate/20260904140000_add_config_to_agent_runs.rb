# Con qué configuración corrió cada agente (F9 · P2).
#
# La pantalla de AGENTES pasa a ser editable, y eso abre un agujero de
# procedencia que no existía mientras `agent_configs` solo se sembraba: si
# MORFEO revisó un artefacto con `derived_ratio_threshold` al 25 % y mañana
# alguien lo sube al 40 %, el artefacto publicado —que es inmutable y no se
# puede reescribir— queda sin forma de explicar bajo qué política se aprobó.
#
# La configuración vigente contesta «cómo se revisa HOY». Esta columna contesta
# «cómo se revisó ESTO», que es otra pregunta y la que importa cuando alguien
# audita un evolutivo cerrado hace tres meses.
#
# Va en `agent_runs` y no versionando `agent_configs` porque el hecho es la
# ejecución, no el ajuste: el run ya es una fila que se escribe una vez y no se
# toca, así que la procedencia viaja con lo que la produjo.
class AddConfigToAgentRuns < ActiveRecord::Migration[8.0]
  def change
    add_column :agent_runs, :config, :jsonb, default: {}, null: false
  end
end
