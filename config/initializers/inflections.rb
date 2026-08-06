# Be sure to restart your server when you modify this file.

# El plural correcto de «definition of done» es «definitions of done»: se
# pluraliza el sustantivo, no la locución entera. Rails, por defecto, produce
# `definition_of_dones`.
#
# Se arregla aquí y no con `to_table:` en cada referencia porque la inflexión
# gobierna varias cosas a la vez —el nombre de tabla del modelo, la clave
# foránea que genera `t.references`, los helpers de ruta— y parchearlas una a
# una deja el hueco justo en la que se olvide.
# Y `criterion` es un plural latino que Rails tampoco conoce: produce
# `criterions`. Se declara el genérico y el compuesto, porque la regla del
# genérico no alcanza al nombre compuesto.
ActiveSupport::Inflector.inflections(:en) do |inflect|
  inflect.irregular "definition_of_done", "definitions_of_done"
  inflect.irregular "criterion", "criteria"
  inflect.irregular "dod_criterion", "dod_criteria"
end

# Y el español, que la aplicación usa en cada `pluralize` de una vista. Sin
# reglas para `:es`, `pluralize(5, "evolutivo")` devuelve «5 evolutivo»: Rails no
# encuentra ninguna y deja la palabra como está.
#
# Las reglas se comprueban de la última a la primera, así que van de lo general
# a lo específico.
ActiveSupport::Inflector.inflections(:es) do |inflect|
  inflect.plural(/$/, "s")                              # vocal → +s
  inflect.plural(/([^aeiouáéíóú])$/i, '\1es')           # consonante → +es
  inflect.plural(/z$/i, "ces")                          # vez → veces

  inflect.singular(/s$/i, "")
  inflect.singular(/([^aeiouáéíóú])es$/i, '\1')
  inflect.singular(/ces$/i, "z")
end
