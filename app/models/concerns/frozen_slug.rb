# Un slug que se elige una vez y no se mueve nunca.
#
# **Por qué esto no es una preferencia de estilo.** El slug del proyecto es el
# primer segmento de la clave de todos sus artefactos
# —`artifacts://identia-interno/rediseno-interfaz/…`— y el del evolutivo es el
# segundo. Esas claves viven en un bucket sin borrado y dentro de citas escritas
# en markdown inmutable. Cambiar un slug después no renombra nada: deja huérfanas
# todas las claves ya emitidas y convierte en mentira cada cita que las nombra.
#
# Es la misma regla que `Platform::Projection::FROZEN` aplica al slug de cliente
# desde F8, y por la misma razón. Aquí va como concern porque a partir de F11 hay
# dos modelos con la propiedad.
#
# La guarda es de modelo y no de controlador **aunque matrix no tenga ningún
# `update`**: es cinturón y tirantes, y sobre todo es lo que un test de invariante
# puede afirmar sin montar una petición.
module FrozenSlug
  extend ActiveSupport::Concern

  included do
    before_update :refuse_slug_change
  end

  private
    def refuse_slug_change
      return unless slug_changed?

      raise ActiveRecord::ReadOnlyRecord,
            "el slug se congela al crear: las claves de artefacto dependen de él " \
            "(#{slug_was.inspect} → #{slug.inspect})"
    end
end
