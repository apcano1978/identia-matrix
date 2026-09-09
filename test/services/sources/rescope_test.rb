# frozen_string_literal: true

require "test_helper"

# Volver a decidir qué fuentes entran. Lo que se prueba aquí es que aplica LA
# MISMA regla que el alta —marcar todo lo ofrecido significa «no hay recorte»— y
# que diferenciar en vez de reescribir conserva lo que no se puede recomputar.
class Sources::RescopeTest < ActiveSupport::TestCase
  setup do
    @client = build_client(slug: "vivla")
    @project = project_for(@client)
    @initiative = build_initiative(client: @client, code: "ev-031")

    @uno = build_document(client: @client, slug: "acta-precios", body: "Lo acordado.")
    @dos = build_document(client: @client, slug: "glosario-negocio", body: "El glosario.")
    @tres = build_document(client: @client, slug: "tarifario", body: "Las tarifas.")
  end

  # ── Recortar ───────────────────────────────────────────────────────────────

  test "marcar menos de lo ofrecido sella el ámbito" do
    Sources::Rescope.call(initiative: @initiative, sources: [ @uno ])

    assert_predicate @initiative, :sources_scoped?
    assert_equal [ @uno ], Sources::Scope.in_scope(@initiative)[:documents].sources
  end

  test "y no marcar ninguna sella con cero: el evolutivo se queda sin fuentes" do
    Sources::Rescope.call(initiative: @initiative, sources: [])

    assert_predicate @initiative, :sources_scoped?
    assert_equal 0, Sources::Scope.in_scope(@initiative).values.sum(&:size)
  end

  # ⚠ LA RAMA QUE HACE REVERSIBLE EL RECORTE. Marcarlo todo NO es «acotar a
  # todo»: es decir que no hay recorte. La diferencia se ve mañana — un ámbito
  # acotado a las tres de hoy no recibiría la cuarta.
  test "volver a marcarlo todo dessella, y con ello vuelve la herencia" do
    Sources::Rescope.call(initiative: @initiative, sources: [ @uno ])
    Sources::Rescope.call(initiative: @initiative, sources: [ @uno, @dos, @tres ])

    refute_predicate @initiative, :sources_scoped?
    assert_equal 0, @initiative.initiative_sources.count

    cuarto = build_document(client: @client, slug: "anexo", body: "El anexo.")
    assert_includes Sources::Scope.in_scope(@initiative)[:documents].sources, cuarto
  end

  # Y la prueba de que no es lo mismo: acotado a las tres, la cuarta no entra.
  test "mientras que acotado a lo mismo menos una, lo nuevo ya no entra solo" do
    Sources::Rescope.call(initiative: @initiative, sources: [ @uno, @dos ])
    cuarto = build_document(client: @client, slug: "anexo", body: "El anexo.")

    assert_not_includes Sources::Scope.in_scope(@initiative)[:documents].sources, cuarto
  end

  # ── Diferencia, no reescribe ───────────────────────────────────────────────

  # ⚠ `refs_count` NO se puede recomputar desde aquí: cuenta las referencias en
  # el corpus indexado, que es otra cosa que las citas emitidas. Borrar y recrear
  # lo pondría a cero y el «7 refs» de la pantalla pasaría a ser mentira.
  test "la fila que sigue conserva sus referencias" do
    fila = InitiativeSource.create!(initiative: @initiative, source: @uno, refs_count: 7)
    @initiative.update!(sources_scoped_at: Time.current)

    Sources::Rescope.call(initiative: @initiative, sources: [ @uno, @dos ])

    assert_equal fila.id, @initiative.initiative_sources.find_by(source: @uno).id
    assert_equal 7, @initiative.initiative_sources.find_by(source: @uno).refs_count
  end

  test "la que sale se va y la que entra se crea" do
    InitiativeSource.create!(initiative: @initiative, source: @uno, refs_count: 7)
    @initiative.update!(sources_scoped_at: Time.current)

    Sources::Rescope.call(initiative: @initiative, sources: [ @dos ])

    assert_equal [ @dos ], @initiative.initiative_sources.reload.map(&:source)
  end

  # ── Lo que se puede conservar aunque ya no se ofrezca ─────────────────────

  # Un documento acotado y luego RETIRADO sigue siendo del ámbito de este
  # evolutivo: retirar saca de lo disponible, no de lo ya acotado. Quien edite el
  # ámbito tiene que poder conservarlo, o se lo quitaríamos sin que lo pidiera.
  test "un acotado que después se retiró se puede mantener" do
    documento = build_project_document(project: @project, title: "Acta vieja",
                                       body: "Lo acordado.")
    InitiativeSource.create!(initiative: @initiative, source: documento)
    @initiative.update!(sources_scoped_at: Time.current)
    documento.update!(retired_at: Time.current)

    Sources::Rescope.call(initiative: @initiative, sources: [ documento, @uno ])

    assert_includes @initiative.initiative_sources.reload.map(&:source), documento
  end

  # ── INVARIANTE 10 ─────────────────────────────────────────────────────────

  test "una fuente de otro cliente se rechaza y no cambia nada" do
    Sources::Rescope.call(initiative: @initiative, sources: [ @uno ])
    ajena = build_document(client: build_client(slug: "caser"), slug: "acta-ajena",
                           body: "De otro.")

    error = assert_raises(Sources::Rescope::Refused) do
      Sources::Rescope.call(initiative: @initiative, sources: [ @uno, ajena ])
    end

    assert_match "acta-ajena", error.message
    assert_equal [ @uno ], @initiative.initiative_sources.reload.map(&:source)
  end

  test "ni un documento subido a otro proyecto del mismo cliente" do
    otro = Project.create!(platform_client_id: @client.id, slug: "vivla-dos",
                           name: "Vivla dos", opened_at: Time.current)
    ajeno = build_project_document(project: otro, title: "Acta ajena", body: "De otro.")

    assert_raises(Sources::Rescope::Refused) do
      Sources::Rescope.call(initiative: @initiative, sources: [ ajeno ])
    end
  end

  # ── Lo que no tiene cuerpo ────────────────────────────────────────────────

  # No se ofrece marcado —no viajaría igual— así que dejarlo fuera no es
  # recortar. Es la misma regla que el alta, y tiene que serlo: si las dos
  # pantallas no dijeran lo mismo, una de ellas mentiría.
  test "dejar fuera lo que no tiene cuerpo no cuenta como recortar" do
    build_document(client: @client, slug: "escaneado", body: nil)

    Sources::Rescope.call(initiative: @initiative, sources: [ @uno, @dos, @tres ])

    refute_predicate @initiative, :sources_scoped?
  end
end
