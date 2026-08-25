# El slug de un documento o de una reunión proyectados.
#
# **No es cosmético: va dentro de citas inmutables.** `[src:doc/acta-precios#p2]`
# lleva el slug en el locator, así que un slug que no case con la gramática de
# F0 convierte en no-parseable una cita ya emitida, dentro de un artefacto que
# nadie puede reescribir.
#
# platform no manda slugs: los deriva matrix. Y los deriva AQUÍ y no en
# `Platform::HttpSource` porque resolver una colisión exige mirar la base de
# datos, y la regla de una fuente es que no la toca.
#
# **Lo único que `parameterize` no resuelve** es el título que no deja nada
# aprovechable —«···», o solo espacios—: da cadena vacía, y la columna es NOT
# NULL. Los puntos no son problema: `parameterize` ya los convierte en guiones,
# así que un «SLA 99.9 %» sale `sla-99-9` y vale igual para un documento que
# para el sufijo de una reunión, que es el más estricto de los dos.
module Platform::Slug
  module_function

  # Deriva un slug libre para `model` a partir de `title`.
  #
  # `fallback` lleva el `platform_id` dentro para que sea único y estable: el
  # mismo documento produce el mismo slug la próxima vez que se sincronice.
  def derive(model, title, fallback:)
    free(model, normalize(title).presence || normalize(fallback))
  end

  def normalize(text) = text.to_s.parameterize

  # El primero libre: `acta-precios`, `acta-precios-2`, `acta-precios-3`.
  #
  # Determinista por orden de primera sincronización. Un sufijo numérico es feo;
  # renombrar retroactivamente sería peor, porque rompería citas ya emitidas.
  #
  # El 1 no se usa: el primero es el slug pelado, y `acta-precios-1` daría a
  # entender que existe un `acta-precios` distinto.
  def free(model, base)
    return base unless taken?(model, base)

    (2..).each do |suffix|
      candidate = "#{base}-#{suffix}"
      return candidate unless taken?(model, candidate)
    end
  end

  def taken?(model, slug) = model.exists?(slug: slug)
end
