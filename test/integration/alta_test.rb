require "test_helper"

# P1 · las dos primeras altas de matrix, por la ruta.
#
# Lo que se prueba aquí y no en el servicio: que la frontera de cliente entra
# por la URL, que la autorización deniega, y que la lista blanca de escrituras
# sigue siendo cierta desde fuera.
class AltaTest < ActionDispatch::IntegrationTest
  include DomainBuilders

  setup do
    @client = build_client(slug: "vivla")
    @repo = build_repository(client: @client, name: "booking-core")
    @user = build_platform_user(role: :admin)
    sign_in_as @user
  end

  # ── Evolutivo ──────────────────────────────────────────────────────────────

  test "abrir un evolutivo lleva a su ficha, y nace en NEED" do
    post client_initiatives_path(@client),
         params: { title: "Unificar precios", repository_ids: [ @repo.id ] }

    initiative = Initiative.sole
    assert_redirected_to client_initiative_path(@client, initiative)
    assert initiative.at_need?

    follow_redirect!
    assert_response :success
    assert_match "Unificar precios", response.body
  end

  test "sin repositorio vuelve a la ficha del cliente y lo dice" do
    post client_initiatives_path(@client), params: { title: "Sin nada" }

    assert_redirected_to client_path(@client)
    assert_match(/repositorio/i, flash[:alert])
    assert_equal 0, Initiative.count
  end

  test "el repositorio de otro cliente no se puede enlazar desde la ruta" do
    # La frontera de cliente entra por la URL: el `client_slug` manda, y los
    # repositorios se buscan DENTRO de él. Un id ajeno no encuentra nada.
    ajeno = build_repository(client: build_client(slug: "caser"), name: "de-otro")

    post client_initiatives_path(@client),
         params: { title: "Intruso", repository_ids: [ ajeno.id ] }

    assert_equal 0, Initiative.count, "se coló un repositorio de otro cliente"
  end

  test "un proyecto de otro cliente tampoco" do
    otro = build_client(slug: "caser")
    proyecto = Platform::Record.writing do
      Platform::Project.create!(platform_id: next_platform_id, platform_client: otro,
                                platform_project_ref: "proj-9999", name: "Ajeno")
    end

    post client_initiatives_path(@client),
         params: { title: "Con proyecto ajeno", repository_ids: [ @repo.id ],
                   platform_project_id: proyecto.id }

    assert_nil Initiative.sole.platform_project,
               "se vinculó un proyecto que no es de este cliente"
  end

  # ── Repositorio ────────────────────────────────────────────────────────────

  test "registrar un repositorio con su git y su CI" do
    post client_repositories_path(@client),
         params: { name: "pricing-svc", default_branch: "develop",
                   remote_url: "git@github.com:vivla/pricing-svc.git",
                   ci_provider: "github", ci_repo_slug: "vivla/pricing-svc" }

    repository = @client.repositories.find_by!(name: "pricing-svc")
    assert_redirected_to client_repository_path(@client, repository)
    assert_equal "develop", repository.default_branch
    assert repository.ci_configured?, "con proveedor y slug, admite verificación"
  end

  test "sin CI se registra igual, y la ficha dirá que no verifica" do
    # Nulo significa «este repositorio no admite verificación automática», y así
    # se dice en su ficha en vez de fingir que verifica (F10).
    post client_repositories_path(@client), params: { name: "docs.site" }

    repository = @client.repositories.find_by!(name: "docs.site")
    assert_equal "main", repository.default_branch
    assert_not repository.ci_configured?
  end

  test "un nombre repetido dentro del cliente se rechaza con su motivo" do
    post client_repositories_path(@client), params: { name: "booking-core" }

    assert_redirected_to client_path(@client)
    assert flash[:alert].present?
    assert_equal 1, @client.repositories.where(name: "booking-core").count
  end

  test "el mismo nombre en OTRO cliente sí vale" do
    otro = build_client(slug: "caser")

    post client_repositories_path(otro), params: { name: "booking-core" }

    assert_equal 1, otro.repositories.where(name: "booking-core").count
  end

  # ── Autorización ───────────────────────────────────────────────────────────

  test "quien no puede entrar en matrix no puede dar de alta" do
    sign_out
    marketing = build_platform_user(role: :marketing)
    sign_in_as marketing

    post client_initiatives_path(@client),
         params: { title: "No debería", repository_ids: [ @repo.id ] }

    assert_equal 0, Initiative.count
  end

  test "sin sesión tampoco" do
    sign_out

    post client_repositories_path(@client), params: { name: "colado" }

    assert_equal 1, Repository.count
  end
end
