require "test_helper"

class ShellSmokeTest < ActionDispatch::IntegrationTest
  setup { DesignSeed.call }

  test "sin sesion la raiz manda al login" do
    get root_path
    assert_redirected_to new_session_path

    get new_session_path
    assert_response :success
    assert_select "h1", "I D E N T I A - M A T R I X"
  end

  test "un admin entra y el armazon se pinta" do
    sign_in_as Platform::User.find_by!(platform_id: 1)
    follow_redirect!

    assert_response :success
    assert_select "nav a", minimum: 3
    assert_match "identia-matrix", response.body
    assert_match "esperan humano", response.body
  end

  test "marketing no entra" do
    marketing = Platform::Record.writing do
      Platform::User.create!(platform_id: 9001, email_address: "m@identia.com",
                             name: "M", role: :marketing)
    end
    sign_in_as marketing

    assert_redirected_to new_session_path
    assert_match "no tiene acceso", flash[:alert]
  end

  test "el rail resalta la entrada que toca en cada vista" do
    sign_in_as Platform::User.find_by!(platform_id: 1)

    { root_path => "DASHBOARD", clients_path => "CLIENTES",
      client_path("vivla") => "CLIENTES", agents_path => "AGENTES" }.each do |path, label|
      get path
      assert_response :success
      on = css_select("a.rail-entry-on .rail-label").map(&:text)
      assert_equal [ label ], on, "en #{path}"
    end
  end

  test "el resumen y el badge cuentan lo mismo" do
    sign_in_as Platform::User.find_by!(platform_id: 1)
    get root_path

    waiting = Dashboard::Board.new.awaiting_human.size
    assert_match "#{waiting} esperan humano", response.body
    assert_equal waiting.to_s, css_select("nav span.bg-antique-gold").first.text
  end

  test "cada vista declara su breadcrumb" do
    sign_in_as Platform::User.find_by!(platform_id: 1)

    { root_path => "status", clients_path => "clients",
      client_path("vivla") => "clients/vivla",
      client_initiative_path("vivla", "ev-031") => "clients/vivla/ev-031",
      client_repository_path("vivla", "booking-core") => "clients/vivla/repos/booking-core",
      agents_path => "agents/tank" }.each do |path, crumb|
      get path
      assert_equal crumb, css_select("header span.text-antique-gold").first.text
    end
  end

  test "diagnostics sigue en pie y sin autenticar" do
    get diagnostics_path

    assert_response :success
    assert_match "Postgres", response.body
  end
end
