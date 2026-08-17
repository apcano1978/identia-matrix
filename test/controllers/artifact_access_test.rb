# frozen_string_literal: true

require "test_helper"

# P3 · quién puede descargar los bytes de un artefacto.
#
# Los controladores de proxy de Active Storage no heredan de
# ApplicationController: sin la guarda, cualquiera con la URL firmada descarga
# el artefacto de cualquier cliente sin sesión.
class ArtifactAccessTest < ActionDispatch::IntegrationTest
  setup do
    @client = build_client(slug: "vivla")
    @initiative = build_initiative(client: @client, code: "ev-031")
    @artifact = publish_artifact(initiative: @initiative, kind: :spec,
                                 body: "# Secreto del cliente\n")
    @url = rails_storage_proxy_path(@artifact.body)
  end

  test "sin sesión no se descarga" do
    get @url

    assert_response :not_found
  end

  # 404 y NO 403: un 403 confirmaría que el artefacto existe. Y desde aquí
  # tampoco se puede redirigir al login — ActiveStorage::DisableSession pone
  # `session_options[:skip]`, así que el `return_to` se perdería en silencio.
  test "y el 404 no filtra que exista" do
    get @url

    assert_response :not_found
    assert_empty response.body
  end

  test "con sesión de alguien con acceso, se descarga el documento entero" do
    sign_in_as build_platform_user(role: :admin)

    get @url

    assert_response :success
    assert_includes response.body, "# Secreto del cliente"
    assert_includes response.body, "key: #{@artifact.storage_key}",
                    "los bytes llevan su front-matter"
  end

  test "un rol sin acceso a matrix recibe 404, no 403" do
    sign_in_as build_platform_user(role: :marketing)

    get @url

    assert_response :not_found
  end

  test "y un usuario deshabilitado tampoco entra" do
    sign_in_as build_platform_user(role: :admin, disabled: true)

    get @url

    assert_response :not_found
  end

  # La trampa más fácil de no ver: `ProxyController#show` hace
  # `http_cache_forever public: true`, y con Thruster y kamal-proxy delante una
  # respuesta `public` se serviría sin volver a pasar por Rails. La policy
  # quedaría de adorno a partir de la segunda petición.
  test "la respuesta no se puede cachear en ningún intermediario" do
    sign_in_as build_platform_user(role: :admin)

    get @url

    assert_response :success
    assert_equal "private, no-store", response.headers["Cache-Control"]
  end

  # Matrix no guarda otra cosa que artefactos: un blob suelto ya es una
  # anomalía y se trata como inexistente.
  test "un blob que no es de un artefacto no se sirve" do
    sign_in_as build_platform_user(role: :admin)
    blob = ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new("suelto"), filename: "x.md", content_type: "text/markdown")

    get rails_storage_proxy_path(blob)

    assert_response :not_found
  end

  private
    def sign_in_as(user, **)
      super
      follow_redirect! if response.redirect?
    end
end
