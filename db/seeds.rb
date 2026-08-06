# Vacío a propósito.
#
# Los datos de la maqueta se siembran con `bin/rails matrix:seed_design`, que es
# idempotente y se niega a correr en producción. `db:seed` no tiene esas dos
# protecciones y se ejecuta solo desde `db:setup` y `db:reset` — en
# identia-platform ya costó una resiembra destructiva de categorías y
# presupuestos.
