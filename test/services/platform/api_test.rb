require "test_helper"

class Platform::ApiTest < ActiveSupport::TestCase
  def api_with(&block)
    stubs = Faraday::Adapter::Test::Stubs.new(&block)
    conn  = Faraday.new { |f| f.adapter(:test, stubs) }
    [ Platform::Api.new(token: "t", connection: conn), stubs ]
  end

  test "compone la ruta bajo /internal/v1 y devuelve el cuerpo parseado" do
    api, stubs = api_with do |stub|
      stub.post("/internal/v1/authenticate") { [ 200, {}, '{"user":{"role":"admin"}}' ] }
    end

    response = api.post("authenticate", email_address: "a@b.c", password: "x")

    assert response.ok?
    assert_equal "admin", response.body.dig("user", "role")
    stubs.verify_stubbed_calls
  end

  test "un 401 llega como respuesta, no como excepción" do
    api, = api_with do |stub|
      stub.post("/internal/v1/authenticate") { [ 401, {}, '{"error":"credenciales inválidas"}' ] }
    end

    response = api.post("authenticate", {})

    assert response.unauthorized?
    assert_not response.ok?
  end

  test "que platform no conteste es un error distinto de que conteste mal" do
    api, = api_with do |stub|
      stub.post("/internal/v1/authenticate") { raise Faraday::ConnectionFailed, "nadie escucha" }
    end

    assert_raises(Platform::Api::Unreachable) { api.post("authenticate", {}) }
  end

  test "una respuesta que no es JSON no se traga en silencio" do
    api, = api_with do |stub|
      stub.post("/internal/v1/authenticate") { [ 200, {}, "<html>vaya</html>" ] }
    end

    assert_raises(Platform::Api::Unexpected) { api.post("authenticate", {}) }
  end

  test "sin token emitido, `for` dice cuál falta y no llama a nadie" do
    ENV.delete("PLATFORM_API_TOKEN_AUTH")

    error = assert_raises(Platform::Api::Error) { Platform::Api.for(:auth) }
    assert_includes error.message, "PLATFORM_API_TOKEN_AUTH"
  end

  test "cada sujeto lee su propia variable" do
    assert_equal "PLATFORM_API_TOKEN_AUTH",   Platform::Api::SUBJECTS[:auth]
    assert_equal "PLATFORM_API_TOKEN_SYSTEM", Platform::Api::SUBJECTS[:system]
    assert_equal "PLATFORM_API_TOKEN_TANK",   Platform::Api::SUBJECTS[:tank]
  end
end
