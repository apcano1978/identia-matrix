# frozen_string_literal: true

require "test_helper"

# `events` es la ÚNICA tabla con dos fronteras, y es deliberado.
#
# «SYNC vivla · 14 docs» es un hecho DEL CLIENTE: ocurre antes de que exista
# ningún proyecto y no tendría a cuál apuntar. «ev-031 avanza a NEO» es del
# proyecto. Los eventos tienen legítimamente las dos dimensiones, y por eso
# conservaron `platform_client_id` cuando las otras siete la perdieron.
#
# Lo que hay que vigilar es que las dos no se contradigan. Este test nació dentro
# del andamio temporal de la mudanza —`the_two_columns_agree_test`— y se rescató
# al borrarlo: aquello era andamio, esto es un invariante.
class AnEventBelongsToOneOrTwoFrontiersTest < ActiveSupport::TestCase
  test "un evento con proyecto y cliente no puede nombrar a dos distintos" do
    initiative = build_initiative
    Pipeline::Escalate.call(initiative: initiative, reason: :inconclusive_environment)

    discrepan = Event.where.not(project_id: nil).where.not(platform_client_id: nil)
                     .reject { |evento| evento.project.platform_client_id == evento.platform_client_id }

    assert_empty discrepan.map(&:id),
                 "hay eventos cuyo proyecto es de otro cliente del que dicen"
  end

  test "un evento de sincronizacion es del cliente y de ningun proyecto" do
    # Es la razón de que la columna se quedara. Si algún día este test se pone
    # rojo porque alguien le puso proyecto, la pregunta no es cuál ponerle: es
    # por qué un hecho del cliente tendría uno.
    cliente = build_client(slug: "vivla")
    Platform::Sync.stub(:record_event, nil) { nil } # no se usa; se deja explícito el escenario

    evento = Event.create!(occurred_at: Time.current, actor: "SYNC",
                           kind: "platform_synced", platform_client: cliente,
                           message: "#{cliente.slug} · solo lectura")

    assert_nil evento.project_id
    assert_equal cliente, evento.platform_client
  end
end
