# frozen_string_literal: true

require "test_helper"

# La regla dura del vocabulario de matrix, verificada.
#
#   REPOSITORIO  Repository   un repositorio de código · eje de memoria
#   EVOLUTIVO    Initiative   la unidad de trabajo     · eje de pipeline
#   PROYECTO     Platform::Project   lo que platform llama proyecto
#
# La palabra `project` NO se usa en el código de matrix bajo ningún concepto.
# Solo aparece bajo el namespace Platform o con el prefijo platform_.
#
# Este test existe porque la ambigüedad tiene tres puertas de entrada, y todas
# son fáciles de cruzar sin darse cuenta:
#
#  1. Dentro de `module Platform`, la constante `Project` a secas RESUELVE. Un
#     `Project.find(1)` escrito ahí funciona y lee como si fuera del dominio.
#  2. La maqueta aprobada llama `project` a la vista del evolutivo (goProject,
#     crumbs.project, state.view === "project"). Portarla literalmente importa
#     el problema.
#  3. platform tiene su propio `projects.ref`; al cachearlo, la columna tiene
#     que llamarse platform_project_ref, no ref.
class VocabularyTest < ActiveSupport::TestCase
  # Los directorios donde vive código nuestro. No se mira db/schema.rb (lo
  # genera Rails) ni vendor.
  SCANNED = %w[app lib config/routes.rb].freeze

  # Rutas donde `project` SÍ es legítimo, porque son la proyección de platform.
  ALLOWED_PATHS = [
    %r{\Aapp/models/platform/},
    %r{\Aapp/services/platform/},
    %r{\Aapp/serializers/platform/},
    %r{\Aapp/policies/platform/},
    %r{\Aapp/views/platform/}
  ].freeze

  # Formas prohibidas. Cada una con el error concreto que representa.
  FORBIDDEN = {
    /\bProject\b(?<!Platform::Project)/ => "la constante Project a secas",
    /\bproject_id\b/                    => "la clave foránea project_id sin prefijo",
    /\bprojects_controller\b/           => "un controlador projects_controller",
    /\bprojects_path\b/                 => "un helper de ruta projects_path",
    /\bhas_many :projects\b/            => "una asociación :projects",
    /\bbelongs_to :project\b/           => "una asociación :project"
  }.freeze

  test "la palabra project no aparece sin calificar" do
    offenses = []

    scanned_files.each do |path|
      relative = path.relative_path_from(Rails.root).to_s
      next if ALLOWED_PATHS.any? { |allowed| allowed.match?(relative) }

      path.each_line.with_index(1) do |line, number|
        next if comment_or_string_exempt?(line)

        FORBIDDEN.each do |pattern, description|
          # `platform_project` y `platform_projects` son la forma correcta:
          # se neutralizan antes de buscar la incorrecta.
          candidate = line.gsub(/platform_projects?/, "").gsub("Platform::Project", "")
          next unless candidate.match?(pattern)

          offenses << "#{relative}:#{number} · #{description}\n    #{line.strip}"
        end
      end
    end

    assert_empty offenses, <<~MSG
      El vocabulario de matrix no admite la palabra `project` sin calificar.
      Un evolutivo es un Initiative; un proyecto de platform es un
      Platform::Project y su clave, platform_project_id.

      #{offenses.join("\n")}
    MSG
  end

  test "las tablas del esquema respetan el vocabulario" do
    schema = Rails.root.join("db/schema.rb")
    skip "todavía no hay esquema" unless schema.exist?

    tables = schema.read.scan(/create_table "([^"]+)"/).flatten

    bad = tables.select { |table| table == "projects" }
    assert_empty bad, "la tabla `projects` no existe en matrix: sería platform_projects"
  end

  test "platform_project y Platform::Project son formas legitimas" do
    # La regla prohíbe `project` sin calificar, no la proyección de platform.
    # Si esto se pusiera rojo, la guarda sería inservible: bloquearía justo el
    # nombre correcto.
    line = "  belongs_to :platform_project, class_name: \"Platform::Project\"\n"
    candidate = line.gsub(/platform_projects?/, "").gsub("Platform::Project", "")

    FORBIDDEN.each_key do |pattern|
      refute_match pattern, candidate, "la forma calificada no debería infringir #{pattern.source}"
    end
  end

  private

  def scanned_files
    patrones = SCANNED.map do |entry|
      Rails.root.join(entry).file? ? entry : "#{entry}/**/*.{rb,erb,yml,js}"
    end

    scan_sources(*patrones).map { |file| Pathname.new(file) }
  end

  # Este propio test nombra las formas prohibidas para poder buscarlas; y los
  # comentarios que EXPLICAN la regla también las nombran. Ninguno de los dos
  # es una infracción.
  def comment_or_string_exempt?(line)
    line.strip.start_with?("#") || line.include?("VOCABULARIO-OK")
  end
end
