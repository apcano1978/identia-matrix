# frozen_string_literal: true

require "test_helper"

# El ámbito es un FILTRO, no una copia. Lo que se prueba aquí es esa frase:
# heredado es el complemento exacto de acotado, y una fuente puede estar en dos
# ámbitos a la vez sin duplicarse.
class Sources::ScopeTest < ActiveSupport::TestCase
  setup do
    @client = build_client(slug: "vivla")
    @initiative = build_initiative(client: @client, code: "ev-031")
    @otro = build_initiative(client: @client, code: "ev-014")

    @acotado = build_document(client: @client, slug: "acta-precios")
    @heredado = build_document(client: @client, slug: "glosario-negocio")
    @reunion = build_meeting(client: @client, slug: "unificacion-precio")

    scope!(@initiative, @acotado, refs: 7)
    scope!(@initiative, @reunion, refs: 5)
  end

  test "en ámbito es lo que se acotó, con sus referencias" do
    scoped = Sources::Scope.scoped(@initiative)

    assert_equal [ @acotado ], scoped[:documents].sources
    assert_equal [ @reunion ], scoped[:meetings].sources
    assert_equal 7, scoped[:documents].refs_for(@acotado)
  end

  # La regla entera: no hay una segunda tabla ni una marca de «heredado». Lo
  # heredado es, por definición, lo que no está acotado.
  test "heredado es el complemento exacto de lo acotado" do
    inherited = Sources::Scope.inherited(@initiative)

    assert_equal [ @heredado ], inherited[:documents].sources
    assert_empty inherited[:meetings].sources

    todo = Platform::Document.where(platform_client: @client).count
    assert_equal todo,
                 Sources::Scope.scoped(@initiative)[:documents].size +
                 inherited[:documents].size
  end

  test "un evolutivo sin ámbito propio lo hereda todo" do
    inherited = Sources::Scope.inherited(@otro)

    assert_equal 2, inherited[:documents].size
    assert_equal 1, inherited[:meetings].size
    assert_equal 0, Sources::Scope.scoped(@otro).values.sum(&:size)
  end

  # El mismo documento, en dos ámbitos, sin duplicarse en ninguno.
  test "una fuente en dos ámbitos aparece como compartida en los dos" do
    scope!(@otro, @acotado, refs: 3)

    desde_031 = Sources::Scope.shared(@initiative)
    desde_014 = Sources::Scope.shared(@otro)

    assert_equal [ @otro ], Sources::Scope.also_in(desde_031, @acotado)
    assert_equal [ @initiative ], Sources::Scope.also_in(desde_014, @acotado)
    assert_equal 1, Platform::Document.where(slug: "acta-precios").count
  end

  test "una fuente acotada a un solo evolutivo no se marca como compartida" do
    assert_empty Sources::Scope.also_in(Sources::Scope.shared(@initiative),
                                        @reunion)
  end

  # INVARIANTE 10: la pantalla existe para hacer inspeccionable la frontera, así
  # que sería raro que fuera el único sitio que la cruza.
  test "el material de otro cliente no aparece en ninguna de las dos listas" do
    ajeno = build_document(client: build_client(slug: "caser"))

    assert_not_includes Sources::Scope.inherited(@initiative)[:documents].sources,
                        ajeno
    assert_not_includes Sources::Scope.scoped(@initiative)[:documents].sources,
                        ajeno
  end

  # ── El tercer origen: lo SUBIDO al proyecto (F12) ─────────────────────────

  test "los documentos del proyecto son un origen aparte del cliente" do
    propio = build_project_document(project: @initiative.project,
                                    title: "Acta arranque", body: "Lo acordado.")

    own = Sources::Scope.own(@initiative)

    assert_equal [ propio ], own[:documents].sources
    # No se cuela entre lo del cliente: son dos consultas y dos fronteras.
    assert_not_includes Sources::Scope.inherited(@initiative)[:documents].sources,
                        propio
  end

  test "y un proyecto propio, que no hereda nada, sí tiene los suyos" do
    proyecto = build_own_project(slug: "identia-interno")
    evolutivo = build_initiative(project: proyecto, code: "ev-900")
    propio = build_project_document(project: proyecto, title: "Acta arranque",
                                    body: "Lo acordado.")

    assert_equal [ propio ], Sources::Scope.own(evolutivo)[:documents].sources
    assert_empty Sources::Scope.inherited(evolutivo)[:documents].sources
  end

  # Retirar saca del ámbito POR DEFECTO. Es la mitad de lo que significa; la
  # otra mitad —que las citas ya emitidas siguen resolviendo— la prueba
  # `Citations::Resolve`.
  test "un documento retirado sale de lo disponible" do
    propio = build_project_document(project: @initiative.project,
                                    title: "Acta vieja", body: "Ya no vale.")
    propio.update!(retired_at: Time.current)

    assert_empty Sources::Scope.own(@initiative)[:documents].sources
  end

  # ⚠ Pero NO sale de lo ya acotado: un evolutivo en marcha no pierde una fuente
  # bajo los pies porque alguien retire el documento desde la ficha.
  test "pero no de lo que ya estaba acotado" do
    propio = build_project_document(project: @initiative.project,
                                    title: "Acta viva", body: "Vale.")
    scope!(@initiative, propio, refs: 2)
    propio.update!(retired_at: Time.current)

    assert_includes Sources::Scope.scoped(@initiative)[:documents].sources, propio
  end

  test "y uno acotado deja de estar en lo disponible, como los de platform" do
    propio = build_project_document(project: @initiative.project,
                                    title: "Acta arranque", body: "Lo acordado.")
    scope!(@initiative, propio, refs: 1)

    assert_empty Sources::Scope.own(@initiative)[:documents].sources
    assert_includes Sources::Scope.scoped(@initiative)[:documents].sources, propio
  end

  # INVARIANTE 10, del lado propio: `own` filtra por `project_id`, así que el
  # documento de otro proyecto del MISMO cliente tampoco aparece.
  test "el documento de otro proyecto del mismo cliente no aparece" do
    otro_proyecto = Project.create!(platform_client_id: @client.id,
                                    slug: "vivla-dos", name: "Vivla dos",
                                    opened_at: Time.current)
    ajeno = build_project_document(project: otro_proyecto, title: "Acta ajena",
                                   body: "De otro proyecto.")

    assert_not_includes Sources::Scope.own(@initiative)[:documents].sources, ajeno
  end

  # ── `in_scope`: lo que de verdad viaja ────────────────────────────────────

  test "in_scope devuelve lo acotado cuando hay filas" do
    in_scope = Sources::Scope.in_scope(@initiative)

    assert_equal [ @acotado ], in_scope[:documents].sources
    assert_equal [ @reunion ], in_scope[:meetings].sources
    assert_not_includes in_scope[:documents].sources, @heredado
  end

  # ⚠ EL DEFECTO QUE B4 ARREGLA. «La ausencia de fila ES la herencia» era verdad
  # en la pantalla y mentira en el payload: un evolutivo recién abierto mandaba
  # cero fuentes mientras su pantalla enseñaba las del cliente.
  test "y sin ninguna fila devuelve todo lo disponible, propio y heredado" do
    propio = build_project_document(project: @otro.project,
                                    title: "Acta arranque", body: "Lo acordado.")

    in_scope = Sources::Scope.in_scope(@otro)

    assert_equal 0, @otro.initiative_sources.count
    assert_includes in_scope[:documents].sources, propio
    assert_includes in_scope[:documents].sources, @acotado
    assert_includes in_scope[:documents].sources, @heredado
    assert_equal [ @reunion ], in_scope[:meetings].sources
  end

  test "y lo propio va primero, que es lo más cercano al evolutivo" do
    propio = build_project_document(project: @otro.project,
                                    title: "Acta arranque", body: "Lo acordado.")

    assert_equal propio, Sources::Scope.in_scope(@otro)[:documents].sources.first
  end

  private
    # ⚠ SELLA, que es lo que hace la aplicación. Desde B5 el ámbito lo decide la
    # fecha y no el conteo de filas: escribir filas sin sellar deja un evolutivo
    # que enseña un ámbito recortado y hereda todo, que es justo la
    # incoherencia que la columna vino a cerrar.
    def scope!(initiative, source, refs:)
      InitiativeSource.create!(initiative: initiative, source: source,
                               refs_count: refs)
      initiative.update!(sources_scoped_at: Time.current)
    end
end
