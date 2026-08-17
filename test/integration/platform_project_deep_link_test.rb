# frozen_string_literal: true

require "test_helper"

# §6 · el enlace desde identia-platform a los artefactos de matrix.
#
# Platform no necesita saber nada de matrix salvo la plantilla de la URL, que
# construye con la `ref` que ya tiene. Y matrix no expone API en sentido
# inverso: hoy basta con atravesar.
class PlatformProjectDeepLinkTest < ActionDispatch::IntegrationTest
  setup do
    @client = build_client(slug: "vivla")
    @project = Platform::Record.writing do
      Platform::Project.create!(platform_id: 2291, platform_project_ref: "proj-2291",
                                name: "Precio y calendario", platform_client: @client)
    end
    @user = build_platform_user(role: :admin)
  end

  test "sin sesión te manda al login, y al entrar aterrizas en el enlace" do
    with_two_initiatives

    get platform_project_deep_link_path("proj-2291")
    assert_redirected_to new_session_path

    sign_in_as @user

    assert_redirected_to platform_project_deep_link_url("proj-2291")
  end

  test "con sesión lista los evolutivos y sus artefactos publicados" do
    with_two_initiatives
    sign_in_as @user

    get platform_project_deep_link_path("proj-2291")

    assert_response :success
    assert_includes response.body, "ev-031"
    assert_includes response.body, "ev-014"
    assert_includes response.body, "spec-031"
  end

  # Se atraviesa hacia la PANTALLA, no hacia los bytes: el artefacto se lee con
  # su procedencia al lado.
  test "y enlaza a la pantalla del evolutivo, no al blob" do
    with_two_initiatives
    sign_in_as @user

    get platform_project_deep_link_path("proj-2291")

    assert_includes response.body, "artifact=spec-031"
    assert_not_includes response.body, "/rails/active_storage/"
  end

  test "con un solo evolutivo se atraviesa directamente" do
    initiative = build_initiative(client: @client, code: "ev-031",
                                  platform_project: @project)
    sign_in_as @user

    get platform_project_deep_link_path("proj-2291")

    assert_redirected_to client_initiative_path(@client, initiative)
  end

  # Ref desconocida y cliente ajeno colapsan en la misma rama: desde fuera son
  # indistinguibles, y ése es el punto. Un 403 confirmaría que existe.
  test "una referencia que no existe da 404" do
    sign_in_as @user

    get platform_project_deep_link_path("proj-9999")

    assert_response :not_found
  end

  # Quien no puede leer ese cliente recibe lo mismo que quien pide una
  # referencia inventada: 404. Un 403 confirmaría que el proyecto existe.
  #
  # Se prueba forzando la respuesta de la policy porque hoy no hay forma de
  # tener sesión sin poder leer todos los clientes: un rol sin acceso a matrix
  # ni siquiera puede entrar, y el alcance por cliente llega en F8. Cuando
  # llegue, este test ya está escrito.
  test "y quien no puede leer ese cliente recibe 404, no 403" do
    with_two_initiatives
    sign_in_as @user

    denying_client_access do
      get platform_project_deep_link_path("proj-2291")
    end

    assert_response :not_found
    assert_not_includes response.body, "ev-031"
  end

  private
    # Niega el acceso por cliente durante el bloque. Redefinir el método y
    # restaurarlo es blunt, pero es lo que hay: el controlador carga su propia
    # instancia desde la sesión, así que un doble sobre un objeto no sirve.
    def denying_client_access
      original = Platform::User.instance_method(:may_read_client?)
      Platform::User.define_method(:may_read_client?) { |_client| false }

      yield
    ensure
      Platform::User.define_method(:may_read_client?, original)
    end

    def with_two_initiatives
      %w[ev-031 ev-014].each do |code|
        initiative = build_initiative(client: @client, code: code,
                                      platform_project: @project)
        publish_artifact(initiative: initiative, kind: :spec)
      end
    end

    def sign_in_as(user, **)
      super
    end
end
