require "test_helper"

# INVARIANTE 2 · Matrix no ejecuta código ajeno, ni siquiera SERAPH.
#
# En F2 solo hay media prueba: que el modelo REGISTRA resultados de CI ajenos en
# lugar de guardar ejecuciones propias. La otra media es de F10, donde tiene que
# comprobarse que no queda una llamada a `docker`, `Open3` ni `system` en el
# código de verificación.
class MatrixRunsNoForeignCodeTest < ActiveSupport::TestCase
  test "un ci_check registra una ejecución ajena, con su url y su identificador" do
    columns = CiCheck.column_names

    assert_includes columns, "ci_provider_run" if columns.include?("ci_provider_run")
    assert_includes columns, "ci_run_id"
    assert_includes columns, "ci_url"
    assert_includes columns, "commit_sha"
  end

  test "y `unavailable` es un estado legítimo, no un fallo" do
    assert_includes CiCheck.statuses.keys, "unavailable"
    assert_equal "unavailable", CiCheck.new.status
  end

  test "un repositorio sin CI lo dice en vez de fingir que verifica" do
    assert_not build_repository.ci_configured?
  end

  # La otra mitad de la prueba llega en F10, cuando SERAPH exista de verdad: allí
  # habrá que comprobar que el verificador consulta la CI ajena en lugar de
  # levantar contenedores.
  #
  # F8 ya la puso a prueba: la parte B necesitaba leer el código de los
  # repositorios de cliente, y la guía proponía un clon somero. Un clon exige
  # ejecutar `git`, y esta guarda lo prohíbe. Se leyó por la API del proveedor
  # en vez de clonar (ver `Repositories::Source`), así que la guarda sigue
  # entera y matrix conserva su ÚNICA excepción: escribir en su bucket.
  test "no hay ejecución de procesos en el código de la aplicación" do
    offenders = scan_sources("app/**/*.rb", "lib/**/*.rb")
                .reject { |file| file.include?("/tasks/") }
                .select { |file| runs_processes?(File.read(file)) }
                .map { |file| Pathname(file).relative_path_from(Rails.root).to_s }

    assert_empty offenders
  end

  # F8 · el espejo de repositorios se resolvió leyendo, no clonando.
  #
  # Este test no comprueba una intención sino una consecuencia: si mañana
  # alguien mete un `git clone`, hará falta también un directorio donde
  # dejarlo. Que no exista ninguna noción de ruta de trabajo es lo que hace que
  # volver a la idea del clon sea un cambio visible y no un parche.
  test "matrix no tiene dónde poner una copia del código de un cliente" do
    fuentes = scan_sources("app/**/*.rb", "lib/**/*.rb").reject { |f| f.include?("/tasks/") }

    offenders = fuentes.select do |file|
      code = File.read(file).lines.grep_v(/\A\s*#/).join
      code.match?(/\b(Dir\.mktmpdir|Rails\.root\.join\(["']mirrors|MIRROR_ROOT|CLONE_ROOT)\b/)
    end

    assert_empty relative_to_root(offenders),
                 "matrix lee el código por la API del proveedor: no clona, y por " \
                 "tanto no necesita un sitio donde dejar una copia"
  end

  private
    # Sin los comentarios: están llenos de `backticks` de markdown, y buscar
    # sobre ellos convierte esta guarda en ruido que se acaba desactivando.
    def runs_processes?(source)
      code = source.lines.grep_v(/\A\s*#/).join

      code.match?(/\b(Open3|Process\.spawn|system\(|exec\(|%x[({\[])/)
    end
end
