# El PROYECTO, y con él la raíz del modelo cambia de sitio (F11).
#
# Hasta ahora la raíz era `Platform::Client`, que es una PROYECCIÓN DE SOLO
# LECTURA de identia-platform. Eso bastaba mientras todo el trabajo de matrix
# fuera de un cliente, y deja de bastar en cuanto aparece un proyecto propio
# —«matrix interna» es el primero— que no tiene cliente detrás y no puede
# colgar de una fila que matrix no escribe.
#
# **La naturaleza del proyecto la decide la ausencia de la clave foránea, no una
# columna de tipo.** Un enum `kind: [de_cliente, propio]` podría discrepar de la
# realidad —una fila marcada «propio» con cliente, o al revés— y habría que
# vigilarlo. Una clave foránea nula no puede mentir.
#
# **El slug se HEREDA del cliente, no se deriva de nuevo.** Es el primer segmento
# de todas las claves de artefacto ya emitidas
# —`artifacts://vivla/ev-031/dod-031/v2.md`— y esas claves no se pueden
# reescribir: viven dentro de markdown inmutable y dentro de citas. Derivarlo otra
# vez podría dar `vivla-2` por una colisión y romperlas todas. Por eso el slug de
# cliente se congeló en F8, y por eso aquí se copia.
#
# Y por lo mismo NO se valida longitud máxima en la columna: los slugs de cliente
# los deriva `Platform::Slug` con `parameterize`, que no tiene tope, y una razón
# social larga pasa de cuarenta caracteres sin esfuerzo. Un tope aquí habría
# reventado el backfill contra datos reales sin que se viera en desarrollo, donde
# el más largo son ocho letras. El tope es una regla del formulario de alta, donde
# alguien escribe un título; no de la raíz del modelo.
#
# Se crea un proyecto por cada cliente CON TRABAJO —evolutivos o repositorios—.
# Un cliente admitido que todavía no tiene nada no necesita proyecto: entró para
# reunir documentación, y esa cuelga de él (P16).
class CreateProjects < ActiveRecord::Migration[8.1]
  def up
    create_table :projects do |t|
      t.string :slug, null: false
      t.string :name, null: false
      # NULLABLE, y su ausencia ES el proyecto propio.
      t.bigint :platform_client_id
      t.datetime :opened_at, null: false

      t.timestamps
    end

    add_index :projects, :slug, unique: true
    add_index :projects, :platform_client_id
    add_foreign_key :projects, :platform_clients

    execute <<~SQL.squish
      INSERT INTO projects (slug, name, platform_client_id, opened_at, created_at, updated_at)
      SELECT c.slug,
             c.name,
             c.id,
             COALESCE((SELECT MIN(i.opened_at) FROM initiatives i
                       WHERE i.platform_client_id = c.id), NOW()),
             NOW(),
             NOW()
        FROM platform_clients c
       WHERE EXISTS (SELECT 1 FROM initiatives i WHERE i.platform_client_id = c.id)
          OR EXISTS (SELECT 1 FROM repositories r WHERE r.platform_client_id = c.id)
    SQL
  end

  def down
    drop_table :projects
  end
end
