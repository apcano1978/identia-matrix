# frozen_string_literal: true

require "test_helper"

# La regla dura del vocabulario de matrix, verificada.
#
#   REPOSITORIO  Repository          un repositorio de código · eje de memoria
#   EVOLUTIVO    Initiative          la unidad de trabajo     · eje de pipeline
#   PROYECTO     Project             la raíz de matrix        · la frontera
#   PROYECTO     Platform::Project   lo que platform llama proyecto: un contrato
#                                    comercial. Otra cosa, con el mismo nombre.
#
# ── LA REGLA SE INVIRTIÓ EN F11, Y NO SE BORRÓ ────────────────────────────────
#
# Hasta F11 la palabra `project` no se usaba en matrix bajo ningún concepto: solo
# aparecía bajo el namespace Platform o con el prefijo platform_. Esa regla nació
# porque «proyecto» significaba UNA cosa —el contrato comercial de platform— y
# usarla para otra era la ambigüedad que había que evitar.
#
# Desde F11 significa DOS, así que la regla ya no puede ser «no la escribas». Pasa
# a ser **«nunca `Project` sin decir de cuál»**, y de las tres puertas de entrada
# que el test original documentaba solo sigue viva la primera:
#
#  1. Dentro de `module Platform`, la constante `Project` A SECAS RESUELVE a
#     `Platform::Project`. Un `Project.find(1)` escrito ahí compila, funciona, y
#     lee como si hablara de la raíz de matrix. Sigue siendo un error, y es el
#     único que queda que no puede detectar el compilador.
#  2. ~~La maqueta llama `project` a la vista del evolutivo.~~ Sigue siendo un
#     error —un evolutivo es un `Initiative`— pero ya no se caza por la palabra:
#     lo cazan las aserciones estructurales de abajo, que exigen que cada
#     asociación resuelva a la clase que le toca.
#  3. ~~La columna tiene que llamarse platform_project_ref.~~ Igual: la comprueba
#     el esquema, no una regex.
#
# ⚠ **Y al invertirla, el escaneo pasa a mirar MUCHO menos código.** Ese es el
# riesgo de este fichero: una guarda que mira poco se apaga sin que nadie lo note.
# Por eso hay un control positivo —un caso que TIENE que marcar— y tres
# afirmaciones estructurales que no dependen de leer texto.
class VocabularyTest < ActiveSupport::TestCase
  # Solo el namespace de la proyección. Fuera de él, `Project` es la raíz de
  # matrix y escribirlo es lo correcto.
  SCANNED = %w[
    app/models/platform
    app/services/platform
    app/serializers/platform
    app/policies/platform
    app/views/platform
    lib/platform
  ].freeze

  # La única forma que sigue prohibida, y solo dentro de Platform.
  FORBIDDEN = {
    /\bProject\b/ => "la constante Project a secas dentro de `module Platform`, " \
                     "donde resuelve a Platform::Project y lee como si fuera la raíz de matrix"
  }.freeze

  test "dentro de Platform, Project a secas es un error" do
    offenses = []

    scanned_files.each do |path|
      relative = path.relative_path_from(Rails.root).to_s

      path.each_line.with_index(1) do |line, number|
        next if comment_or_string_exempt?(line)

        FORBIDDEN.each do |pattern, description|
          next unless infringes?(line, pattern)

          offenses << "#{relative}:#{number} · #{description}\n    #{line.strip}"
        end
      end
    end

    assert_empty offenses, <<~MSG
      Dentro de `module Platform`, escribe `Platform::Project` con su namespace.
      A secas resuelve igual y dice otra cosa: la raíz de matrix es `Project`.

      #{offenses.join("\n")}
    MSG
  end

  # ── EL CONTROL POSITIVO ─────────────────────────────────────────────────────
  #
  # Restringir el escaneo es lo que puede apagar esta guarda, y una guarda apagada
  # pasa en verde. Estos dos casos comprueban que el matcher sigue sabiendo
  # distinguir: marca la forma mala y deja pasar la buena.
  test "el matcher marca la forma ambigua y deja pasar las tres calificadas" do
    mala = "    Project.find_by(platform_project_ref: ref)\n"
    buenas = [
      "    belongs_to :platform_project, class_name: \"Platform::Project\"\n",
      # La raíz de matrix, nombrada desde dentro de `module Platform`. Es la
      # forma que hay que escribir ahí, y la guarda la marcaba: se descubrió
      # ejecutando B4, con este mismo test.
      "      ::Project.create!(platform_client_id: client.id)\n",
      "    ref = platform_project.platform_project_ref\n"
    ]

    FORBIDDEN.each_key do |pattern|
      assert infringes?(mala, pattern),
             "la guarda tiene que marcar `Project` a secas: si no, no está mirando nada"

      buenas.each do |buena|
        refute infringes?(buena, pattern),
               "la forma calificada no debería infringir: #{buena.strip}"
      end
    end
  end

  # ── LO ESTRUCTURAL ──────────────────────────────────────────────────────────
  #
  # Tres afirmaciones que no dependen de leer texto, y que son las que de verdad
  # sostienen la regla ahora que hay dos proyectos.

  test "las dos tablas existen, y son dos" do
    tables = ActiveRecord::Base.connection.tables

    assert_includes tables, "projects",
                    "la raíz de matrix vive en `projects` desde F11"
    assert_includes tables, "platform_projects",
                    "y la proyección del contrato comercial sigue siendo otra tabla"
  end

  test "toda columna project_id apunta a la raíz de matrix" do
    connection = ActiveRecord::Base.connection

    mal = connection.tables.flat_map do |table|
      next [] unless connection.columns(table).any? { |column| column.name == "project_id" }

      clave = connection.foreign_keys(table).find { |fk| fk.column == "project_id" }

      if clave.nil?
        [ "#{table}.project_id no tiene clave foránea" ]
      elsif clave.to_table != "projects"
        [ "#{table}.project_id apunta a #{clave.to_table}, no a projects" ]
      else
        []
      end
    end

    assert_empty mal, <<~MSG
      `project_id` nombra siempre la raíz de matrix. Lo que apunte a la proyección
      de platform se llama `platform_project_id`, y así se distinguen sin leerlo.

      #{mal.join("\n  ")}
    MSG
  end

  test "cada asociacion resuelve al proyecto que dice su nombre" do
    # ⚠ `eager_load!` NO es decoración. En el entorno de test `eager_load` está en
    # false, así que sin esto `descendants` devuelve CERO modelos y este test pasa
    # en verde sin haber mirado ninguno — se comprobó, y era exactamente lo que
    # hacía la primera versión. Es el mismo agujero que documenta SourceScan, por
    # otra puerta: aquí el glob que no encuentra nada es la lista de clases.
    #
    # Y por eso además se afirma el mínimo: si un refactor volviera a vaciar la
    # lista, esto se pone rojo en vez de dejar de proteger en silencio.
    modelos = models_de_dominio

    assert_operator modelos.size, :>=, 30,
                    "solo #{modelos.size} modelos cargados: la guarda no está mirando el dominio"

    mal = modelos.flat_map do |modelo|
      # Singulares y PLURALES. La primera versión solo miraba las de
      # pertenencia, y `has_many :projects` dentro de `module Platform` se
      # coló apuntando a `Platform::Project`: Rails lo infiere del namespace,
      # no de la palabra.
      [
        [ :project, Project ], [ :platform_project, Platform::Project ],
        [ :projects, Project ], [ :platform_projects, Platform::Project ]
      ].filter_map do |nombre, esperada|
        reflection = modelo.reflect_on_association(nombre)
        next if reflection.nil? || reflection.klass == esperada

        "#{modelo.name}##{nombre} resuelve a #{reflection.klass}, no a #{esperada}"
      end
    end

    assert_empty mal, <<~MSG
      Dentro de `module Platform`, Rails deduce `Project` como `Platform::Project`
      y fuera como `Project`: la asociación tiene que decir cuál con `class_name:`.

      #{mal.join("\n  ")}
    MSG
  end

  private

  def infringes?(line, pattern)
    # `platform_project`, `platform_projects`, `Platform::Project` y **`::Project`**
    # son las formas CORRECTAS: se neutralizan antes de buscar la incorrecta, o
    # cada una contaría como infracción de sí misma.
    #
    # `::Project` es la que se olvida, y es justo la que hay que escribir dentro
    # de `module Platform` para nombrar la raíz de matrix sin ambigüedad. Sin
    # neutralizarla, la guarda prohibiría la única forma correcta que queda ahí
    # dentro — y eso no es una guarda estricta, es una guarda rota.
    candidate = line.gsub(/platform_projects?/, "")
                    .gsub("Platform::Project", "")
                    .gsub("::Project", "")

    candidate.match?(pattern)
  end

  def models_de_dominio
    Rails.application.eager_load!
    ApplicationRecord.descendants.reject(&:abstract_class?)
  end

  def scanned_files
    patrones = SCANNED.map do |entry|
      Rails.root.join(entry).file? ? entry : "#{entry}/**/*.{rb,erb,yml,js}"
    end

    # El mínimo sube respecto al escaneo antiguo justo porque ahora se mira menos:
    # con el umbral por defecto, borrar `app/services/platform` entero dejaría el
    # test en verde.
    scan_sources(*patrones, minimum: 10).map { |file| Pathname.new(file) }
  end

  # Este propio test nombra la forma prohibida para poder buscarla; y los
  # comentarios que EXPLICAN la regla también la nombran. Ninguno de los dos es
  # una infracción.
  def comment_or_string_exempt?(line)
    line.strip.start_with?("#") || line.include?("VOCABULARIO-OK")
  end
end
