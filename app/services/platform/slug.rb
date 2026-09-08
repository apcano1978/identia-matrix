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
  # `scope` acota la búsqueda de colisiones. Es ADITIVO: sin él la unicidad se
  # mira sobre la tabla entera, que es como se comportaba antes de F11 y como
  # siguen necesitándolo documentos y reuniones.
  #
  # Lo estrena `Initiative`, cuyo slug es único DENTRO del proyecto: dos
  # proyectos pueden tener cada uno su `rediseno-interfaz`, y sin el ámbito el
  # segundo se llamaría `rediseno-interfaz-2` sin motivo.
  #
  # `among` son OTRAS tablas donde el mismo nombre también estorbaría, ya
  # acotadas por quien llama. Lo estrena F12: un documento subido y uno de
  # platform se citan igual —`[src:doc/acta-precios]`— y viven en tablas
  # distintas, así que la unicidad tiene que mirar las dos o la cita sería
  # ambigua. Relaciones y no pares modelo+scope: quien llama sabe mejor que esto
  # dónde mirar.
  def derive(model, title, fallback:, scope: {}, among: [])
    free(model, normalize(title).presence || normalize(fallback), scope, among)
  end

  def normalize(text) = text.to_s.parameterize

  # El primero libre: `acta-precios`, `acta-precios-2`, `acta-precios-3`.
  #
  # Determinista por orden de primera sincronización. Un sufijo numérico es feo;
  # renombrar retroactivamente sería peor, porque rompería citas ya emitidas.
  #
  # El 1 no se usa: el primero es el slug pelado, y `acta-precios-1` daría a
  # entender que existe un `acta-precios` distinto.
  def free(model, base, scope = {}, among = [])
    return base unless taken?(model, base, scope, among)

    (2..).each do |suffix|
      candidate = "#{base}-#{suffix}"
      return candidate unless taken?(model, candidate, scope, among)
    end
  end

  def taken?(model, slug, scope = {}, among = [])
    return true if model.where(scope).exists?(slug: slug)

    among.any? { |relation| relation.exists?(slug: slug) }
  end
end
