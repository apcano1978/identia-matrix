# frozen_string_literal: true

# Escanear el código fuente sin que la guarda se apague sola.
#
# **P5.** Seis tests de invariante y de arquitectura comprueban su regla
# recorriendo ficheros con `Dir[]` y afirmando `assert_empty offenders`. Todos
# comparten el mismo agujero: **si el glob no encuentra nada, `offenders` está
# vacío y el test pasa** — verde, rápido y sin haber comprobado nada.
#
# No es teórico. Basta con renombrar un directorio, mover `app/services` o
# cambiar la extensión de una plantilla para que la guarda deje de mirar donde
# tiene que mirar, y nada lo diga. Un test verde que no afirma nada es peor que
# no tenerlo, porque compra confianza que no ha ganado.
#
# `scan_sources` glob-ea y **exige haber encontrado algo**. La cifra mínima es
# deliberadamente floja: no se trata de fijar cuántos ficheros hay —eso sería un
# test que se rompe cada semana— sino de distinguir «no hay infracciones» de
# «no he mirado».
module SourceScan
  # Por debajo de esto, el escaneo no ha encontrado el código: matrix tiene 46
  # ficheros solo en `app/models`.
  MINIMUM = 5

  def scan_sources(*patterns, minimum: MINIMUM)
    files = Dir[*patterns.map { |p| Rails.root.join(p).to_s }]

    assert_operator files.size, :>=, minimum,
                    "el escaneo encontró #{files.size} ficheros en #{patterns.join(', ')}: " \
                    "la guarda está mirando donde no hay código y pasaría en verde sin comprobar nada"

    files
  end

  # Los mismos, ya relativos a la raíz, que es como se leen en un mensaje de fallo.
  def relative_to_root(paths)
    paths.map { |path| Pathname(path).relative_path_from(Rails.root).to_s }
  end
end

class ActiveSupport::TestCase
  include SourceScan
end
