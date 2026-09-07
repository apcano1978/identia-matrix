# El acta del ARQUITECTO, fila a fila (F11 · B8).
#
# La etapa 1 del pipeline —`need`— registraba el alta y nada más. Con el
# ARQUITECTO pasa a producir algo: una lista de decisiones con tres estados, que
# es lo que la spec necesita para existir y lo que MORFEO levanta como
# advertencia y LINK recupera al cerrar.
#
# **El producto del ARQUITECTO no es prosa: es esta tabla.** El artefacto `acta`
# la publica en markdown congelado, pero lo consultable —«¿qué queda abierto?»—
# es una consulta, no un documento que alguien tenga que leer entero.
#
# ── El ordinal, que es lo delicado ─────────────────────────────────────────
#
# `ordinal` es GLOBAL dentro del evolutivo y no se renumera nunca. Numerarlo
# dentro del estado —«abierta 1, abierta 2»— habría sido más bonito en pantalla
# y habría renumerado al cerrar una decisión: la cita
# `[src:acta/arquitecto-031#abierta-2]`, ya emitida dentro de un artefacto que
# nadie puede reescribir, pasaría a señalar otra pregunta.
#
# El ancla lleva el estado que la decisión tenía AL PUBLICARSE el acta
# —`#abierta-4` es la decisión 4, que entonces estaba abierta— y habla de un
# documento congelado, igual que `#c3` en un DoD.
#
# ── La frontera, desnormalizada ────────────────────────────────────────────
#
# `project_id` va aquí y no se navega desde el evolutivo, por la misma razón que
# en `human_notes` y `artifacts`: el invariante 10 se defiende con un `where`
# sobre una clave foránea, no recorriendo asociaciones. Una consulta que empieza
# por el proyecto no puede devolver material de otro.
class CreateDecisions < ActiveRecord::Migration[8.1]
  def change
    create_table :decisions do |t|
      t.references :initiative, null: false, foreign_key: true
      t.references :project, null: false, foreign_key: true

      t.integer :ordinal, null: false
      # 0 abierta · 1 cerrada · 2 descartada. POSICIONAL: lo que venga después se
      # anexa, como en `agent_runs.agent` y `citations.source_kind`.
      t.integer :status, null: false, default: 0

      t.text :question, null: false
      # Nula mientras está abierta: es exactamente lo que «abierta» significa.
      t.text :answer

      # La cita que respalda la decisión, en crudo —`[src:meet/2026-05-02@22:40]`—
      # para pintarla en la fila. Las filas de `citations` las crea
      # `Artifacts::Publish` al parsear el cuerpo del acta: un solo camino, y no
      # dos formas de registrar una cita.
      t.string :source_citation

      # Qué ejecución la levantó. Nula para las que escribe una persona sin
      # agente por medio, y `nullify` para que borrar un run no borre lo decidido.
      t.references :raised_by_run, foreign_key: { to_table: :agent_runs }

      t.timestamps
    end

    # El ordinal es único DENTRO del evolutivo, y lo impide la base de datos: dos
    # turnos simultáneos que calcularan `max + 1` a la vez se colarían entre la
    # lectura y la escritura.
    add_index :decisions, [ :initiative_id, :ordinal ], unique: true
    add_index :decisions, [ :project_id, :status ]
  end
end
