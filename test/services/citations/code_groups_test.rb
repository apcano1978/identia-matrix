# frozen_string_literal: true

require "test_helper"

class Citations::CodeGroupsTest < ActiveSupport::TestCase
  setup do
    @client = build_client(slug: "vivla")
    @initiative = build_initiative(client: @client, code: "ev-031")
    @artifact = build_artifact(initiative: @initiative, kind: :spec)
    %w[booking-core owner-web pricing-svc].each do |name|
      build_repository(client: @client, name: name)
    end
  end

  # Las cifras del panel de la maqueta: 7 citas de código en 3 repositorios,
  # 4 + 2 + 1.
  test "agrupa las siete citas de código en sus tres repositorios" do
    seed_mockup_citations

    groups = Citations::CodeGroups.call(@artifact.citations.reload)

    assert_equal %w[booking-core owner-web pricing-svc], groups.map(&:name)
    assert_equal [ 4, 2, 1 ], groups.map(&:size)
  end

  test "el commit se enseña una vez por repositorio, no por cita" do
    seed_mockup_citations

    groups = Citations::CodeGroups.call(@artifact.citations.reload)

    assert_equal %w[4f2a9c1 e91b330 b7c0d21], groups.map(&:commit_sha)
    assert_equal [ 1, 1, 1 ], groups.map { |group| group.commits.size }
  end

  # Dos commits distintos para el mismo repositorio dentro de un artefacto es
  # una contradicción, no un promedio. Se enseña como error.
  test "dos commits distintos del mismo repositorio se marcan, no se promedian" do
    cite("[src:code/booking-core:rates.ts#L40@4f2a9c1]")
    cite("[src:code/booking-core:pricing.ts#L12@c31d5a8]")

    group = Citations::CodeGroups.call(@artifact.citations.reload).sole

    assert_predicate group, :divergent?
    assert_equal %w[4f2a9c1 c31d5a8], group.commits
    assert_nil group.commit_sha, "con divergencia no hay un commit del grupo"
  end

  test "ordena por nombre de repositorio, no por el orden de la base" do
    cite("[src:code/pricing-svc:quote.ts#L31@b7c0d21]")
    cite("[src:code/booking-core:rates.ts#L40@4f2a9c1]")

    assert_equal %w[booking-core pricing-svc],
                 Citations::CodeGroups.call(@artifact.citations.reload).map(&:name)
  end

  test "solo mira las citas de código" do
    cite("[src:code/booking-core:rates.ts#L40@4f2a9c1]")
    cite("[src:doc/acta-precios#p2]")
    cite("[src:spec/spec-031#§2]")
    # `verify` lleva calificador de repositorio pero NO es una cita de código:
    # su destino es una línea de un log de CI, no un fichero.
    cite("[src:verify/booking-core:run-174#L88]")

    group = Citations::CodeGroups.call(@artifact.citations.reload).sole

    assert_equal 1, group.size
  end

  test "sin citas de código no hay grupos" do
    cite("[src:doc/acta-precios#p2]")

    assert_empty Citations::CodeGroups.call(@artifact.citations.reload)
  end

  private
    def cite(raw)
      Citations::Attach.one(citable: @artifact, raw: raw, client: @client.id)
    end

    def seed_mockup_citations
      %w[
        [src:code/booking-core:rates.ts#L40@4f2a9c1]
        [src:code/booking-core:pricing.ts#L12@4f2a9c1]
        [src:code/booking-core:calendar.ts#L88@4f2a9c1]
        [src:code/booking-core:cache.ts#L120@4f2a9c1]
        [src:code/owner-web:priceLabel.tsx#L22@e91b330]
        [src:code/owner-web:api.ts#L64@e91b330]
        [src:code/pricing-svc:quote.ts#L31@b7c0d21]
      ].each { |raw| cite(raw) }
    end
end
