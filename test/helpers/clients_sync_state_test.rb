require "test_helper"

# El desfase tiene que VERSE. Si platform no responde, matrix sigue funcionando
# con la proyección cacheada —para eso existe— y lo único inaceptable sería que
# la pantalla no lo dijera.
class ClientsSyncStateTest < ActionView::TestCase
  include ClientsHelper
  include UiHelper
  include DomainBuilders

  test "un cliente sin sincronizar lo dice, en vez de callarse" do
    client = build_client

    assert_match "sin sincronizar", client_sync_state(client)
  end

  test "sincronizado hace un rato se pinta en el tono normal" do
    client = build_client
    Platform::Record.writing { client.update!(sources_synced_at: 10.minutes.ago) }

    salida = client_sync_state(client)
    assert_match "sync", salida
    assert_no_match(/text-glyph-fail/, salida)
  end

  test "pasadas dos horas se pinta en terracota" do
    client = build_client
    Platform::Record.writing { client.update!(sources_synced_at: 3.hours.ago) }

    assert_match(/text-glyph-fail/, client_sync_state(client),
                 "un desfase que no se ve es peor que no tener proyección")
  end

  test "el umbral es el de la sincronización, no uno inventado aquí" do
    # Si el helper tuviera su propio número, cambiar el de `Platform::Sync` no
    # cambiaría lo que ve nadie.
    client = build_client
    Platform::Record.writing do
      client.update!(sources_synced_at: (Platform::Sync::STALE_AFTER + 1.minute).ago)
    end

    assert_match(/text-glyph-fail/, client_sync_state(client))
  end
end
