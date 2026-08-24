# frozen_string_literal: true

require "test_helper"

# Publicar un artefacto se hace por un solo sitio: Artifacts::Publish.
#
# Es el mismo test estructural que `one_way_to_cite_test.rb`, y por el mismo
# motivo. Hasta F5 había tres caminos —el seed, el paseo del pipeline y los
# builders de test— y ya habían divergido: el del paseo **no rellenaba la
# columna `front_matter`**, así que sus artefactos salían con `{}` dentro y nadie
# lo miraba. Los tres «funcionaban»; lo que fallaba era el acuerdo entre ellos.
#
# Lo que la fase construye —el orden subir-antes-de-registrar, el front-matter
# incrustado, el checksum del cuerpo— solo es cierto si hay una sola puerta.
class OneWayToPublishTest < ActiveSupport::TestCase
  # El único fichero autorizado a crear un artefacto o a adjuntarle bytes.
  PUBLISHER = "app/services/artifacts/publish.rb"

  SCANNED = %w[app lib].freeze

  # Crear la fila y adjuntar los bytes. Las dos mitades tienen que estar en el
  # mismo sitio: separarlas es exactamente cómo se rompe el orden de §2.
  FORBIDDEN = {
    /\bArtifact\.create!?\(/ => "crea un artefacto a mano",
    /\.body\.attach\b/ => "adjunta bytes a mano"
  }.freeze

  test "solo Artifacts::Publish crea artefactos y les adjunta bytes" do
    offenders = FORBIDDEN.flat_map do |pattern, reason|
      sources.filter_map do |path, source|
        next if path == PUBLISHER
        next unless source.match?(pattern)

        "#{path} #{reason}"
      end
    end

    assert_empty offenders,
                 "publicar por otro camino se salta el front-matter, el orden " \
                 "de subida y las citas"
  end

  test "y el seed no vuelve a componer el front-matter por su cuenta" do
    source = Rails.root.join("lib/design_seed.rb").read

    assert_no_match(/def front_matter\b/, source,
                    "el front-matter lo compone Artifacts::Publish")
    assert_match(/Artifacts::Publish\./, source)
  end

  test "el paseo del pipeline publica por el servicio" do
    source = Rails.root.join("lib/pipeline_walk.rb").read

    assert_match(/Artifacts::Publish\./, source)
  end

  # `FrontMatter.render` existe desde F0 y estuvo hasta F5 sin que lo llamara
  # nadie: los bytes almacenados eran el cuerpo pelado y el checksum casaba por
  # accidente. Que tenga exactamente un llamante es lo que hay que conservar.
  test "el front-matter lo escribe exactamente un sitio" do
    callers = sources.select { |_path, source| source.match?(/FrontMatter\.render\b/) }

    assert_equal [ PUBLISHER ], callers.keys
  end

  private
    def sources
      @sources ||= scan_sources(*SCANNED.map { |dir| "#{dir}/**/*.rb" }).to_h do |path|
        [ Pathname(path).relative_path_from(Rails.root).to_s, Pathname(path).read ]
      end
    end
end
