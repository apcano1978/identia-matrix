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
  #
  # Ninguna es `update` ni `destroy`, y no es casualidad: **todo lo que matrix
  # escribe es un ACTO que ocurre una vez y deja constancia**, no la edición de
  # un campo. Firmar, validar, recorrer un paso, autorizar que se cierre sin
  # recorrerlo, dar de alta. Que la lista sea toda de `create` es la propiedad,
  # no el estilo — y las altas de P1 la conservaron sin tener que forzarla.
  ALLOWED = [
    # Entrar y salir. Escribe en `sessions`, que es de matrix.
    "sessions#create",
    "sessions#destroy",

    # INVARIANTE 8 · resolver un conflicto de nivel a favor del origen. Marca
    # el artefacto derivado para revisión SIN tocar su fila.
    "citation_conflict_resolutions#create",

    # ── Las dos puertas (F6) ────────────────────────────────────────────────
    #
    # GATE 1 · irreversible, nominal y con re-autenticación: autoriza a escribir
    # sobre repositorios de un cliente.
    "signatures#create",
    # La cuarta bifurcación: negarse a firmar y devolver a TRINITY con nota.
    "return_to_trinities#create",
    # GATE 2 · reversible por rechazo. Confirma que lo ejecutado sirve.
    "validations#create",

    # ── Las dos altas (F8 · P1) ─────────────────────────────────────────────
    #
    # Las primeras escrituras de matrix con campos de formulario, y las dos son
    # `create`: dar de alta es un acto que ocurre una vez, no la edición de un
    # campo. La propiedad de esta lista sigue intacta.
    #
    # No las acompaña ningún `update` ni `destroy` a propósito. Un evolutivo mal
    # abierto no se corrige: se abre otro y el primero se cierra por el camino
    # que ya existe. Lo contrario obligaría a decidir qué pasa con las citas que
    # ya lo nombran.
    "initiatives#create",
    "repositories#create",

    # ── La guía de pruebas (F6) ─────────────────────────────────────────────
    "walks#create",
    # Levantar la mano sobre un paso que no se puede recorrer…
    "raised_hands#create",
    # …y que OTRA persona autorice cerrarlo sin esa prueba.
    "exemptions#create",

    # ── Poner a trabajar a un agente (F9) ───────────────────────────────────
    #
    # También `create`, y también un acto: lanzar deja una fila en `agent_runs`
    # con quién, cuándo, qué costó y cómo acabó. La propiedad de esta lista
    # —ni un solo `update`— sigue intacta con doce escrituras.
    #
    # No hay `agent_runs#destroy` ni `#update` a propósito. Una ejecución que
    # salió mal no se borra: se relanza, y las dos quedan. Borrarla escondería
    # el coste que ya se pagó y el motivo por el que hubo que repetirla.
    "agent_runs#create"
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
    offenders = scan_sources("app/controllers/**/*.rb").select do |path|
      Pathname(path).read.match?(/Platform::Record\.writing/)
    end

    assert_empty offenders.map { |path| File.basename(path) }
  end
end
