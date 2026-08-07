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

  private
    def scope!(initiative, source, refs:)
      InitiativeSource.create!(initiative: initiative, source: source,
                               refs_count: refs)
    end
end
