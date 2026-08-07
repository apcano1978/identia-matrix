# frozen_string_literal: true

require "test_helper"

# Matrix nunca modifica un origen, y no ejecuta código ajeno. Lo que escribe
# cabe en una lista, y esa lista está aquí.
#
# Hasta F4 la aplicación era de solo lectura entera, y eso se afirmaba pantalla
# por pantalla con `assert_no_selector "main form"`. Esa forma no escala: cada
# pantalla nueva tiene que acordarse de repetirla, y la primera que no lo haga
# abre un hueco silencioso.
#
# Una LISTA BLANCA de verbos no-GET dice lo mismo de una vez y obliga a que la
# próxima escritura se declare aquí — que es exactamente el momento en el que
# conviene pensarlo dos veces.
class MatrixWritesAlmostNothingTest < ActiveSupport::TestCase
  # Todo lo que la aplicación puede escribir, hoy.
  ALLOWED = [
    # Entrar y salir. Escribe en `sessions`, que es de matrix.
    "sessions#create",
    "sessions#destroy",

    # INVARIANTE 8 · resolver un conflicto de nivel a favor del origen. Marca
    # el artefacto derivado para revisión SIN tocar su fila.
    "citation_conflict_resolutions#create"
  ].freeze

  test "la aplicación solo escribe donde está declarado" do
    writes = Rails.application.routes.routes.filter_map do |route|
      verbs = route.verb.to_s.scan(/[A-Z]+/)
      next if verbs.empty? || verbs == [ "GET" ]

      controller = route.defaults[:controller]
      action = route.defaults[:action]
      next if controller.blank?
      # Los motores de Rails traen sus propias rutas —Active Storage sirve
      # ficheros, Action Mailbox recibe correo— y no son código de matrix.
      # Sidekiq va montada como Rack, fuera de ApplicationController.
      next if controller.start_with?("rails/", "active_storage/",
                                     "action_mailbox/")

      "#{controller}##{action}"
    end.uniq.sort

    assert_equal ALLOWED.sort, writes,
                 "hay una escritura nueva sin declarar, o una que sobra"
  end

  # La proyección de platform es de solo lectura fuera de `Platform::Record.writing`,
  # y ningún controlador la abre.
  test "ningún controlador escribe en la proyección de platform" do
    offenders = Dir[Rails.root.join("app/controllers/**/*.rb")].select do |path|
      Pathname(path).read.match?(/Platform::Record\.writing/)
    end

    assert_empty offenders.map { |path| File.basename(path) }
  end
end
