# Reparte el siguiente número de una secuencia, una sola vez cada uno.
#
# Mismo patrón que `identia-platform/app/services/projects/numbering.rb`, que es
# la convención del workspace: **lock consultivo de Postgres dentro de la
# transacción**. Sin él, dos altas simultáneas leen el mismo `last_number` y
# reparten el mismo código; el índice único de `initiatives.code` haría fallar a
# la segunda, que es mejor que un duplicado pero peor que no ocurrir.
#
# El lock se libera solo al terminar la transacción — de ahí `xact`.
module Matrix::Sequence
  module_function

  # `ev-042`. Tres dígitos como mínimo, que es lo que valida `Initiative`, y
  # más cuando haga falta: el evolutivo mil se llama `ev-1000` y sigue casando.
  def next_initiative_code = format("ev-%03d", next_number(MatrixSequence::INITIATIVE))

  def next_package_code = format("pkg-%03d", next_number(MatrixSequence::PACKAGE))

  def next_number(name)
    ApplicationRecord.transaction do
      # La clave del lock sale del nombre y no de un número escrito a mano: dos
      # secuencias distintas no deben esperarse la una a la otra, y un entero
      # elegido a ojo colisiona con el de otra tabla el día que alguien añada la
      # tercera.
      #
      # Saneada y no interpolada. `lock_key` devuelve un entero de un SHA y no
      # hay nada que inyectar, pero eso lo sabe quien lee el método y no quien
      # lee esta línea — ni brakeman, que la marcaba.
      #
      # Y con `execute`, no con `exec_query`: el segundo mapea el tipo del
      # resultado, y `pg_advisory_xact_lock` devuelve `void`, así que suelta un
      # «unknown OID 2278» en el log cada vez que se abre un evolutivo.
      ApplicationRecord.connection.execute(
        ApplicationRecord.sanitize_sql_array(
          [ "SELECT pg_advisory_xact_lock(?)", lock_key(name) ]))

      sequence = MatrixSequence.find_or_create_by!(name: name)
      sequence.last_number.next.tap { |number| sequence.update!(last_number: number) }
    end
  end

  # Un entero con signo de 64 bits, estable entre procesos. `String#hash` NO
  # sirve: Ruby lo aleatoriza en cada arranque, así que dos servidores usarían
  # llaves distintas para la misma secuencia y el lock no bloquearía nada.
  def lock_key(name) = Digest::SHA256.hexdigest(name).to_i(16) % (2**62)
end
