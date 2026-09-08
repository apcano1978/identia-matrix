# El documento SUBIDO a un proyecto (F12 · B1).
#
# Hasta hoy matrix no acepta un solo fichero: toda la documentación llega
# proyectada desde identia-platform, y era deliberado —un documento vive una sola
# vez, en el sitio donde alguien lo gestiona—. F11 rompió esa premisa por un
# lado: `identia-interno` no tiene platform detrás, así que **nace mudo**.
#
# La regla nueva no es «matrix no guarda documentos». Es **«un documento tiene un
# solo dueño, y se ve cuál es»**: por eso `uploaded_by_user` es obligatorio.
#
# ── Se cita igual que uno de platform, y pesa igual ────────────────────────
#
# `[src:doc/acta-precios#p2]` no distingue de dónde viene, y no es una comodidad:
# un acta subida a mano y la misma acta llegada de platform tienen el mismo valor
# probatorio. Lo que cambia es quién responde de ella, y eso se ve en la ficha.
#
# De ahí que el slug sea **único dentro del proyecto venga de donde venga**: se
# comprueba contra esta tabla Y contra `platform_documents` al derivarlo, en las
# dos direcciones. Sin eso, `Citations::Resolve` tendría que elegir en silencio
# entre dos documentos con el mismo nombre — dentro de una cita que ya está
# escrita en markdown inmutable.
#
# ── Los tres estados salen de estas columnas ───────────────────────────────
#
#   sin `extracted_at` ni error   extrayendo el texto
#   con `body`                    citable
#   con `extraction_error`        sin cuerpo extraído, y dice por qué
#
# No hay enum de estado a propósito: un enum paralelo a las columnas puede
# discrepar de ellas, y entonces hay que decidir cuál manda.
#
# Y NO hay columna `kind`: el tipo de fichero lo dice `file.content_type` del
# blob, y una columna al lado sería un segundo sitio donde decir lo mismo.
class CreateProjectDocuments < ActiveRecord::Migration[8.1]
  def change
    create_table :project_documents do |t|
      # La frontera, como en `human_notes` y `artifacts`: el invariante 10 se
      # impone con un `where` sobre una clave foránea, no navegando asociaciones.
      t.references :project, null: false, foreign_key: true
      # Quién responde de él. Es la mitad de la regla nueva, así que es
      # obligatorio: un documento sin dueño visible es lo que esta fase evita.
      t.references :uploaded_by_user, null: false,
                   foreign_key: { to_table: :platform_users }

      # CONGELADO al crear, igual que el del proyecto y el del evolutivo: va
      # dentro de las citas y esas no se reescriben. Lo defiende `FrozenSlug`.
      t.string :slug, null: false
      t.string :title, null: false

      # Nulo hasta que B2 extraiga, y nulo TAMBIÉN si no se pudo. Un PDF
      # escaneado del que nadie sacó texto es un caso real, y decirlo es más
      # honesto que fingir un cuerpo vacío — es la misma decisión que
      # `Platform::Document#body` lleva desde F7.
      t.text :body
      t.datetime :extracted_at
      t.string :extraction_error

      # Retirado NO es borrado. Sale del ámbito de los evolutivos NUEVOS y sigue
      # resolviendo en las citas ya emitidas, que es la misma forma que
      # `missing_since` en la proyección. En matrix no se borra nada.
      t.datetime :retired_at

      t.timestamps
    end

    add_index :project_documents, [ :project_id, :slug ], unique: true
    add_index :project_documents, [ :project_id, :retired_at ]
  end
end
