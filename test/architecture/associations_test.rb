require "test_helper"

# Una asociación mal declarada no falla al arrancar: falla la primera vez que
# alguien la usa, que puede ser meses después y en producción.
#
# Dentro de `module Platform` el riesgo es real y concreto: Rails deduce la
# clave foránea del nombre DESMODULIZADO —`Platform::Client` → `client_id`— y
# las columnas se llaman `platform_client_id`. Esta guarda recorre todas.
class AssociationsTest < ActiveSupport::TestCase
  test "todas las asociaciones resuelven contra columnas que existen" do
    broken = models.flat_map do |model|
      model.reflect_on_all_associations.filter_map do |association|
        check(model, association)
      end
    end

    assert_empty broken
  end

  private
    def models
      Rails.application.eager_load!
      ApplicationRecord.descendants.reject(&:abstract_class?)
    end

    def check(model, association)
      return nil if association.polymorphic?

      association.klass
      model.where(nil).joins(association.name).limit(0).load

      nil
    rescue StandardError => e
      "#{model}##{association.name}: #{e.message.lines.first.strip}"
    end
end
