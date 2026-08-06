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
