require "test_helper"

# Dar de alta un evolutivo. Un evolutivo no es una fila: son tres cosas, y este
# test existe sobre todo para que sigan siendo tres.
class Initiatives::OpenTest < ActiveSupport::TestCase
  include DomainBuilders

  setup do
    @client = build_client(slug: "vivla")
    @repo = build_repository(client: @client, name: "booking-core")
  end

  def abrir(**overrides)
    Initiatives::Open.call(**{ project: project_for(@client), title: "Unificar precios",
                               repositories: [ @repo ], actor: "antonio" }.merge(overrides))
  end

  # ── Las tres cosas ─────────────────────────────────────────────────────────

  test "nace con código, repositorios y su entrada de etapa" do
    initiative = abrir

    assert_match(/\Aev-\d{3,}\z/, initiative.code)
    assert_equal [ @repo ], initiative.repositories.to_a
    assert_equal 1, initiative.stage_entries.count
  end

  test "nace en NEED, activo, y ahí espera" do
    initiative = abrir

    assert initiative.at_need?
    assert initiative.status_active?

    entrada = initiative.stage_entries.sole
    assert entrada.at_need?
    assert entrada.active?
    assert_equal 1, entrada.iteration
    assert entrada.entered_at.present?
    assert_nil entrada.exited_at
  end

  test "el caché se DERIVA de la entrada, no se escribe a mano" do
    # El caché solo es defendible mientras se pueda recomputar. Si el alta lo
    # escribiera aparte, empezaría a discrepar del historial sin que nada lo
    # dijera.
    initiative = abrir

    assert_empty StageCache.rebuild(Initiative.where(id: initiative.id)),
                 "reconstruir el caché cambió algo: el alta lo escribió a mano"
  end

  test "deja constancia en el event stream" do
    assert_difference -> { Event.count }, 1 do
      @initiative = abrir
    end

    evento = Event.order(:id).last
    assert_equal "initiative_opened", evento.kind
    assert_equal @initiative, evento.initiative
    assert_equal @client, evento.platform_client
    assert_includes evento.message, "booking-core"
  end

  # ── La frontera de cliente ─────────────────────────────────────────────────

  test "no se puede enlazar el repositorio de otro cliente" do
    # Un formulario manipulado manda el id que quiera. Enlazar material ajeno
    # metería el código de otro cliente en el ámbito de este evolutivo, que es
    # lo que el invariante 10 existe para impedir.
    ajeno = build_repository(client: build_client(slug: "caser"), name: "de-otro")

    error = assert_raises(Initiatives::Open::Refused) do
      abrir(repositories: [ @repo, ajeno ])
    end

    assert_includes error.message, "de-otro"
    assert_equal 0, Initiative.count, "no debería haber quedado nada a medias"
  end

  # ── Lo que se rechaza ──────────────────────────────────────────────────────

  test "sin título no se abre" do
    assert_raises(Initiatives::Open::Refused) { abrir(title: "  ") }
    assert_equal 0, Initiative.count
  end

  test "sin repositorio no se abre" do
    # Un evolutivo es trabajo SOBRE código: sin repositorio no habría nada que
    # citar, y el invariante 4 prohíbe afirmar sobre código sin repositorio.
    assert_raises(Initiatives::Open::Refused) { abrir(repositories: []) }
    assert_equal 0, Initiative.count
  end

  test "un fallo a mitad no deja media alta" do
    # Las tres cosas van en la misma transacción, por la misma razón que
    # `Pipeline::Transition` agrupa las suyas.
    Event.stub(:create!, ->(*) { raise "el bus de eventos se cayó" }) do
      assert_raises(RuntimeError) { abrir }
    end

    assert_equal 0, Initiative.count
    assert_equal 0, InitiativeRepository.count
    assert_equal 0, StageEntry.count
  end

  # ── Multi-repo y proyecto ──────────────────────────────────────────────────

  test "puede tocar varios repositorios" do
    otro = build_repository(client: @client, name: "owner-web")
    initiative = abrir(repositories: [ @repo, otro ])

    assert initiative.multi_repo?
    assert_equal %w[booking-core owner-web], initiative.repositories.order(:name).pluck(:name)
  end

  test "vincular el proyecto de platform es lo que lo hace alcanzable por el enlace profundo" do
    proyecto = Platform::Record.writing do
      Platform::Project.create!(platform_id: next_platform_id, platform_client: @client,
                                platform_project_ref: "proj-2291", name: "Precios")
    end
    initiative = abrir(platform_project: proyecto)

    assert_equal proyecto, initiative.platform_project
  end

  test "y sin proyecto también se abre" do
    assert_nil abrir.platform_project
  end

  # ── El ámbito documental (F12 · B5) ───────────────────────────────────────
  #
  # La regla entera cabe en una frase: **se sella si lo marcado ≠ lo citable
  # disponible**. Sellar es lo que convierte «recortar» en un acto fechado, y es
  # lo que hace que «ninguna fuente» se pueda decir.

  test "sin hablar de ámbito no se sella nada: se hereda todo" do
    build_document(client: @client, slug: "acta-precios", body: "Lo acordado.")

    initiative = abrir

    refute_predicate initiative, :sources_scoped?
    assert_equal 0, initiative.initiative_sources.count
    assert_equal 1, Sources::Scope.in_scope(initiative).values.sum(&:size)
  end

  # ⚠ Y DEJAR EL MARCADO POR DEFECTO TAMPOCO SELLA. Es la mitad de la regla:
  # quien no recorta sigue heredando lo que se suba mañana, y sellarle el ámbito
  # por haber pulsado «abrir» se lo quitaría sin que lo pidiera.
  test "marcar todo lo citable tampoco: no recortó" do
    uno = build_document(client: @client, slug: "acta-precios", body: "Lo acordado.")
    dos = build_document(client: @client, slug: "glosario-negocio", body: "El glosario.")

    initiative = abrir(sources: [ uno, dos ])

    refute_predicate initiative, :sources_scoped?
    assert_equal 0, initiative.initiative_sources.count
  end

  test "pero desmarcar una sí sella, y el ámbito es lo marcado" do
    uno = build_document(client: @client, slug: "acta-precios", body: "Lo acordado.")
    build_document(client: @client, slug: "glosario-negocio", body: "El glosario.")

    initiative = abrir(sources: [ uno ])

    assert_predicate initiative, :sources_scoped?
    assert_equal [ uno ], Sources::Scope.in_scope(initiative)[:documents].sources
  end

  # ⚠ CERO MARCADAS ES CERO FUENTES, no «todas». Es el «arrancar solo con
  # conversación» del rediseño, y hasta que la fecha existió era inexpresable:
  # cero filas volvía a leerse como herencia.
  test "y no marcar ninguna sella con cero: el evolutivo arranca sin fuentes" do
    build_document(client: @client, slug: "acta-precios", body: "Lo acordado.")

    initiative = abrir(sources: [])

    assert_predicate initiative, :sources_scoped?
    assert_equal 0, initiative.initiative_sources.count
    assert_equal 0, Sources::Scope.in_scope(initiative).values.sum(&:size)
  end

  # Un documento sin cuerpo sale DESMARCADO del formulario y no viajaría igual,
  # así que dejarlo fuera no es recortar.
  test "dejar fuera lo que no tiene cuerpo no cuenta como recortar" do
    citable = build_document(client: @client, slug: "acta-precios", body: "Lo acordado.")
    build_document(client: @client, slug: "escaneado", body: nil)

    refute_predicate abrir(sources: [ citable ]), :sources_scoped?
  end

  # ⚠ Y MARCARLO TAMPOCO, que es lo contrario de lo que este test decía al
  # escribirlo. Recortar es DEJAR FUERA algo que podía entrar; añadir de más una
  # fuente sin cuerpo no quita nada y no cambia lo que el agente recibe, así que
  # no puede congelar el ámbito.
  #
  # La regla se enderezó cuando la pantalla de fuentes contradijo su propio
  # rótulo: decía «márcalo todo para volver a heredarlo todo» y marcarlo todo
  # —incluidas las nueve sin cuerpo del catálogo— no lo hacía.
  test "y marcarlo de más tampoco: añadir no es recortar" do
    citable = build_document(client: @client, slug: "acta-precios", body: "Lo acordado.")
    sin_cuerpo = build_document(client: @client, slug: "escaneado", body: nil)

    refute_predicate abrir(sources: [ citable, sin_cuerpo ]), :sources_scoped?
  end

  # ── Lo adjuntado en el mismo formulario ───────────────────────────────────

  # ⚠ ADJUNTAR NO ES RECORTAR. Nadie pudo marcar una casilla que no existía
  # cuando envió, así que arrastrar un fichero no puede sellar el ámbito por su
  # cuenta — y no hace falta: sin sellar, lo subido entra solo.
  test "adjuntar un documento no sella el ámbito" do
    ya_estaba = build_document(client: @client, slug: "acta-precios", body: "Lo acordado.")
    nuevo = build_project_document(project: project_for(@client), title: "Acta arranque",
                                   body: "Lo acordado ahora.")

    initiative = abrir(sources: [ ya_estaba ], attached: [ nuevo ])

    refute_predicate initiative, :sources_scoped?
    assert_includes Sources::Scope.in_scope(initiative)[:documents].sources, nuevo
  end

  test "y si se recortó, lo adjuntado entra igual" do
    build_document(client: @client, slug: "acta-precios", body: "Lo acordado.")
    build_document(client: @client, slug: "glosario-negocio", body: "El glosario.")
    nuevo = build_project_document(project: project_for(@client), title: "Acta arranque",
                                   body: "Lo acordado ahora.")

    initiative = abrir(sources: [], attached: [ nuevo ])

    assert_predicate initiative, :sources_scoped?
    assert_equal [ nuevo ], initiative.initiative_sources.map(&:source)
  end

  # ── INVARIANTE 10, del lado documental ────────────────────────────────────

  test "una fuente de otro cliente no entra, y el alta se niega entera" do
    ajena = build_document(client: build_client(slug: "caser"), slug: "acta-ajena",
                           body: "De otro.")

    error = assert_raises(Initiatives::Open::Refused) { abrir(sources: [ ajena ]) }

    assert_match "acta-ajena", error.message
    assert_equal 0, Initiative.count
  end

  test "ni un documento subido a otro proyecto del mismo cliente" do
    otro = Project.create!(platform_client_id: @client.id, slug: "vivla-dos",
                           name: "Vivla dos", opened_at: Time.current)
    ajeno = build_project_document(project: otro, title: "Acta ajena", body: "De otro.")

    assert_raises(Initiatives::Open::Refused) { abrir(sources: [ ajeno ]) }
  end

  # Retirar saca del ámbito de los evolutivos NUEVOS, y este es el sitio donde
  # eso se hace verdad: un retirado no está en `available_for`, así que marcarlo
  # es marcar algo que no se ofreció.
  test "ni uno retirado, que ya no se ofrece" do
    retirado = build_project_document(project: project_for(@client), title: "Acta vieja",
                                      body: "Ya no vale.")
    retirado.update!(retired_at: Time.current)

    assert_raises(Initiatives::Open::Refused) { abrir(sources: [ retirado ]) }
  end
end
