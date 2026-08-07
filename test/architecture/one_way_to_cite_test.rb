# frozen_string_literal: true

require "test_helper"

# Crear una cita se hace por un solo sitio: Citations::Attach, que resuelve la
# fuente con Citations::Resolve.
#
# Este test es estructural a propósito. Hasta F4 la misma lógica vivía tres
# veces —dos en el seed y una en el paseo de la máquina de estados— y ya había
# divergido: la copia del paseo creaba citas SIN resolver el `target`, así que
# sus artefactos nacían sin procedencia. Nadie se enteraba porque las tres
# copias «funcionaban»; lo que fallaba era el acuerdo entre ellas.
#
# Una regla que solo vive en la cabeza de quien la escribió vuelve a romperse.
class OneWayToCiteTest < ActiveSupport::TestCase
  # Los sitios que crean citas hoy. Al añadir uno —F9 traerá el del runtime
  # real— tiene que entrar en esta lista, y eso obliga a mirar si delega.
  CALLERS = %w[lib/design_seed.rb lib/pipeline_walk.rb].freeze

  # Las dos funciones que estaban duplicadas. Si reaparece una definición con
  # estos nombres fuera del servicio, la triplicación ha vuelto.
  REVIVED = /def\s+(attach_citations|resolve_target)\b/

  test "ningún llamante vuelve a definir su propia versión" do
    CALLERS.each do |path|
      source = Rails.root.join(path).read

      assert_no_match REVIVED, source,
                      "#{path} define otra vez lo que ya hace Citations::Attach"
    end
  end

  test "los llamantes crean citas a través del servicio, no a mano" do
    CALLERS.each do |path|
      source = Rails.root.join(path).read

      assert_match(/Citations::Attach\./, source,
                   "#{path} tiene que atar sus citas con Citations::Attach")
      assert_no_match(/citations\.create!/, source,
                      "#{path} crea una cita a mano, saltándose la resolución")
    end
  end

  test "solo el servicio resuelve la fuente de una cita" do
    resolvers = Dir[Rails.root.join("app/**/*.rb"), Rails.root.join("lib/**/*.rb")]
                .reject { |path| path.include?("app/services/citations/") }
                .select { |path| Pathname(path).read.match?(/Platform::Meeting\.find_by\(held_on/) }

    assert_empty resolvers.map { |path| Pathname(path).relative_path_from(Rails.root).to_s },
                 "resolver una cita fuera de Citations::Resolve se salta la " \
                 "frontera de cliente y el desempate por sufijo"
  end
end
