require "test_helper"

# El adaptador de GitHub, con el adaptador de prueba de Faraday. Lo que se
# prueba aquí es la traducción y el sha corto; el HTTP de verdad se comprueba a
# mano contra un repositorio real.
class Repositories::GithubSourceTest < ActiveSupport::TestCase
  include DomainBuilders

  setup do
    @client = build_client(slug: "identia")
    @repo = build_repository(client: @client, name: "evalora-core",
                             remote_url: "git@github.com:identia/evalora-core.git")
    @location = Repositories::Remote.parse(@repo.remote_url)
  end

  def con_respuestas(&block)
    stubs = Faraday::Adapter::Test::Stubs.new(&block)
    conn = Faraday.new { |f| f.adapter(:test, stubs) }
    source = Repositories::GithubSource.new(@repo, @location)
    source.instance_variable_set(:@connection, conn)
    [ source, stubs ]
  end

  test "el sha llega CORTO, que es lo que la gramática de citas exige" do
    # `@<sha7>`: un sha de cuarenta no parsea, y convertirlo aquí evita que cada
    # llamante tenga que acordarse.
    source, = con_respuestas do |stub|
      stub.get("/repos/identia/evalora-core/branches/main") do
        [ 200, {}, { "commit" => { "sha" => "f7b2e04c1d9a8b7e6f5a4d3c2b1a0987654321fe" } }.to_json ]
      end
    end

    sha = source.head_sha
    assert_equal "f7b2e04", sha
    assert Citations::Parse.call("[src:code/evalora-core:app.rb#L1@#{sha}]"),
           "el sha que devuelve el adaptador no sirve para una cita"
  end

  test "cuenta ficheros, no directorios" do
    # Contar los `tree` inflaría la cifra que la ficha enseña como «ficheros».
    source, = con_respuestas do |stub|
      stub.get("/repos/identia/evalora-core/git/trees/f7b2e04") do
        [ 200, {}, { "tree" => [
          { "path" => "app", "type" => "tree" },
          { "path" => "app/models/user.rb", "type" => "blob" },
          { "path" => "README.md", "type" => "blob" }
        ] }.to_json ]
      end
    end

    assert_equal 2, source.files_count("f7b2e04")
    assert_not source.truncated?
  end

  test "un árbol truncado por GitHub se puede saber" do
    # Mentir con una cifra parcial sin avisar sería peor que dar la parcial.
    source, = con_respuestas do |stub|
      stub.get("/repos/identia/evalora-core/git/trees/f7b2e04") do
        [ 200, {}, { "truncated" => true, "tree" => [ { "type" => "blob" } ] }.to_json ]
      end
    end

    source.files_count("f7b2e04")
    assert source.truncated?
  end

  test "el fichero llega decodificado y anclado a su commit" do
    source, = con_respuestas do |stub|
      stub.get("/repos/identia/evalora-core/contents/app/rates.rb") do
        [ 200, {}, { "encoding" => "base64",
                     "content" => Base64.encode64("class Rates\nend\n") }.to_json ]
      end
    end

    assert_equal "class Rates\nend\n", source.file("app/rates.rb", "f7b2e04")
  end

  test "un fichero que no está devuelve nulo, no revienta" do
    source, = con_respuestas do |stub|
      stub.get("/repos/identia/evalora-core/contents/no-existe.rb") { [ 404, {}, "{}" ] }
    end

    assert_nil source.file("no-existe.rb", "f7b2e04")
  end

  test "un 500 sí revienta: no es lo mismo que no estar" do
    source, = con_respuestas do |stub|
      stub.get("/repos/identia/evalora-core/branches/main") { [ 500, {}, "{}" ] }
    end

    error = assert_raises(Repositories::GithubSource::Error) { source.head_sha }
    assert_includes error.message, "500"
  end

  test "que GitHub no responda es un error, no una cuenta de cero ficheros" do
    source, = con_respuestas do |stub|
      stub.get("/repos/identia/evalora-core/branches/main") { raise Faraday::ConnectionFailed, "nada" }
    end

    assert_raises(Repositories::GithubSource::Error) { source.head_sha }
  end

  # ── La credencial ──────────────────────────────────────────────────────────

  test "usa la credencial vigente del cliente, y manda la más reciente" do
    RepositoryCredential.create!(platform_client: @client, host: "github.com", token: "vieja")
    nueva = RepositoryCredential.create!(platform_client: @client, host: "github.com", token: "nueva")

    assert_equal nueva, RepositoryCredential.current_for(@client, "github.com")
    assert_equal "nueva", RepositoryCredential.current_for(@client, "github.com").token
  end

  test "la credencial de un cliente no vale para otro" do
    # La frontera de cliente aplicada al acceso, no solo a los datos.
    RepositoryCredential.create!(platform_client: @client, host: "github.com", token: "de-identia")
    otro = build_client(slug: "caser")

    assert_nil RepositoryCredential.current_for(otro, "github.com")
  end

  test "el token va cifrado en la columna" do
    credential = RepositoryCredential.create!(platform_client: @client,
                                              host: "github.com", token: "ghp_secreto")
    crudo = RepositoryCredential.connection.select_value(
      "SELECT token FROM repository_credentials WHERE id = #{credential.id}")

    assert_not_equal "ghp_secreto", crudo
    assert_equal "ghp_secreto", credential.reload.token
  end
end
