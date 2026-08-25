require "test_helper"

# La sincronización, con una fuente de doble en vez de HTTP: lo que se prueba
# aquí es el ÁMBITO, la idempotencia y lo que deja escrito. El HTTP y la
# traducción de nombres son de `Platform::HttpSourceTest`.
class Platform::SyncTest < ActiveSupport::TestCase
  include DomainBuilders

  # Una fuente cualquiera: cinco listas de hashes y un nombre. Es toda la
  # interfaz, y por eso F8 solo tuvo que escribir la otra.
  class Fuente
    def initialize(**listas) = @listas = listas
    def name = "platform"

    %i[clients users projects documents meetings].each do |recurso|
      define_method(recurso) { @listas.fetch(recurso, []) }
    end
  end

  # `discover` trae el catálogo: quién existe. `sincronizar` trae lo de UN
  # cliente. Están separadas en el código por la misma razón por la que aquí son
  # dos ayudantes: una pasada de vivla no puede sellar la ficha de caser.
  def descubrir(fuente)
    Platform::Source.stub(:current, fuente) { Platform::Sync.discover }
  end

  def sincronizar(fuente, client:)
    Platform::Source.stub(:current, fuente) { Platform::Sync.call(client) }
  end

  def cliente(platform_id, name) = { platform_id: platform_id, name: name }

  def documento(platform_id, client_platform_id, title)
    { platform_id: platform_id, client_platform_id: client_platform_id, title: title }
  end

  # ── El ámbito ──────────────────────────────────────────────────────────────
  #
  # Sin esto la fase rompe datos en silencio: sincronizar un cliente sacaría del
  # ámbito los documentos de todos los demás, y sus evolutivos se quedarían sin
  # fuentes sin que nadie hubiera tocado nada.

  test "sincronizar un cliente NO marca ausentes los documentos de otro" do
    descubrir(Fuente.new(clients: [ cliente(101, "Vivla"), cliente(102, "Caser") ]))
    vivla = Platform::Client.find_by!(platform_id: 101)
    caser = Platform::Client.find_by!(platform_id: 102)

    sincronizar(Fuente.new(documents: [ documento(5001, 101, "Acta de vivla") ]), client: vivla)
    sincronizar(Fuente.new(documents: [ documento(5002, 102, "Acta de caser") ]), client: caser)

    # Y ahora otra pasada SOLO de vivla.
    sincronizar(Fuente.new(documents: [ documento(5001, 101, "Acta de vivla") ]), client: vivla)

    assert_nil Platform::Document.find_by(platform_id: 5002).missing_since,
               "el documento de caser no vino porque no se pidió, no porque no exista"
  end

  test "y sí marca ausente lo que desaparece DENTRO de su ámbito" do
    descubrir(Fuente.new(clients: [ cliente(101, "Vivla") ]))
    vivla = Platform::Client.find_by!(platform_id: 101)

    sincronizar(Fuente.new(documents: [ documento(5001, 101, "Acta"),
                                        documento(5002, 101, "Tarifario") ]), client: vivla)
    sincronizar(Fuente.new(documents: [ documento(5001, 101, "Acta") ]), client: vivla)

    assert Platform::Document.find_by(platform_id: 5002).missing_since.present?
    assert_nil Platform::Document.find_by(platform_id: 5001).missing_since
  end

  # ── Idempotencia ───────────────────────────────────────────────────────────

  test "dos pasadas seguidas dan el mismo resultado" do
    descubrir(Fuente.new(clients: [ cliente(101, "Vivla") ]))
    vivla = Platform::Client.find_by!(platform_id: 101)
    fuente = Fuente.new(documents: [ documento(5001, 101, "Acta de precios") ])

    primera = sincronizar(fuente, client: vivla)
    assert_equal 1, primera.report.created

    segunda = sincronizar(fuente, client: vivla)
    assert_equal 0, segunda.report.created
    assert_equal 0, segunda.report.updated
    assert_equal 0, segunda.report.missing
    assert_equal 1, Platform::Document.count
  end

  # ── Lo que congela y lo que refresca ───────────────────────────────────────

  test "renombrar en platform refresca el nombre y NO el slug" do
    descubrir(Fuente.new(clients: [ cliente(101, "Vivla") ]))
    vivla = Platform::Client.find_by!(platform_id: 101)
    sincronizar(Fuente.new(documents: [ documento(5001, 101, "Acta de precios") ]), client: vivla)
    slug = Platform::Document.find_by!(platform_id: 5001).slug

    descubrir(Fuente.new(clients: [ cliente(101, "VIVLA S.L.") ]))
    sincronizar(Fuente.new(documents: [ documento(5001, 101, "Acta de precios · v2") ]), client: vivla)

    documento = Platform::Document.find_by!(platform_id: 5001)
    assert_equal "Acta de precios · v2", documento.title
    assert_equal slug, documento.slug, "el slug va dentro de citas ya emitidas"
    assert_equal "VIVLA S.L.", Platform::Client.find_by!(platform_id: 101).name
  end

  # ── Lo que deja escrito ────────────────────────────────────────────────────

  test "deja constancia en el event stream, colgando del cliente" do
    descubrir(Fuente.new(clients: [ cliente(101, "Vivla") ]))
    vivla = Platform::Client.find_by!(platform_id: 101)

    assert_difference -> { Event.count }, 1 do
      sincronizar(Fuente.new(documents: []), client: vivla)
    end

    evento = Event.order(:id).last
    assert_equal "SYNC", evento.actor
    assert_equal "platform_synced", evento.kind
    assert_equal vivla, evento.platform_client
    assert_nil evento.initiative, "una sincronización no es de ningún evolutivo"
  end

  test "descubrir el catálogo NO sella las fuentes de nadie" do
    # `sources_synced_at` responde «¿está al día lo de este cliente?», y por eso
    # es una columna distinta de `synced_at`. Con una sola, la ficha de un
    # cliente cuyos documentos llevan tres días sin mirarse diría que está al
    # día cada vez que alguien refresca el catálogo — y un desfase invisible es
    # exactamente lo que esta fase existe para evitar.
    descubrir(Fuente.new(clients: [ cliente(101, "Vivla"), cliente(102, "Caser") ]))
    vivla = Platform::Client.find_by!(platform_id: 101)
    caser = Platform::Client.find_by!(platform_id: 102)

    sincronizar(Fuente.new(documents: [ documento(5001, 101, "Acta") ]), client: vivla)

    assert vivla.reload.sources_synced_at.present?
    assert_nil caser.reload.sources_synced_at,
               "de caser no se ha pedido ni un documento"

    travel 1.hour do
      descubrir(Fuente.new(clients: [ cliente(101, "Vivla"), cliente(102, "Caser") ]))
    end

    assert_nil caser.reload.sources_synced_at,
               "refrescar el catálogo no significa haber mirado sus fuentes"
  end

  # ── Cerrar sesiones ────────────────────────────────────────────────────────

  test "quien pierde el acceso en platform pierde su sesión abierta" do
    # La sesión es de matrix y sobreviviría hasta caducar. Es el reverso de tener
    # proyección, y hay que cerrarlo en la sincronización.
    usuario = build_platform_user(role: :admin)
    sesion = Session.create!(platform_user: usuario)

    descubrir(Fuente.new(users: [ { platform_id: usuario.platform_id,
                                    email_address: usuario.email_address,
                                    name: usuario.name, role: "admin",
                                    disabled: true } ]))

    assert_not Session.exists?(sesion.id), "un usuario deshabilitado no sigue dentro"
  end

  test "y quien lo conserva no la pierde" do
    usuario = build_platform_user(role: :admin)
    sesion = Session.create!(platform_user: usuario)

    descubrir(Fuente.new(users: [ { platform_id: usuario.platform_id,
                                    email_address: usuario.email_address,
                                    name: usuario.name, role: "admin",
                                    disabled: false } ]))

    assert Session.exists?(sesion.id)
  end
end
