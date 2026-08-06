require "application_system_test_case"

# El armazón, mirado por un navegador de verdad: que el login entra, que el rail
# mide lo que dice la maqueta y que el scroll vive dentro del panel y no en la
# página.
class ShellTest < ApplicationSystemTestCase
  setup { DesignSeed.call }

  test "se entra por el formulario y aparece el armazon" do
    sign_in_as Platform::User.find_by!(platform_id: 1)

    assert_selector "nav", text: "DASHBOARD"
    assert_text "identia-matrix"
    assert_text "esperan humano"
  end

  test "el rail mide 62 y la barra de titulo 38" do
    sign_in_as Platform::User.find_by!(platform_id: 1)
    # `evaluate_script` no espera; `assert_selector` sí. Sin esto el script corre
    # sobre la página anterior y `querySelector` devuelve null.
    assert_selector "nav"

    assert_equal 62, evaluate_script("document.querySelector('nav').offsetWidth")
    assert_equal 38, evaluate_script("document.querySelector('header').offsetHeight")
  end

  # El lienzo de la maqueta es fijo y no tiene scroll. El nuestro es fluido a
  # partir de 1280, pero la página tampoco scrollea: cada panel lleva el suyo.
  test "la pagina no scrollea" do
    sign_in_as Platform::User.find_by!(platform_id: 1)
    assert_selector "nav"

    assert_equal 0, evaluate_script(
      "document.body.scrollHeight - document.body.clientHeight")
  end

  test "una credencial mala no entra y lo dice sin revelar si la cuenta existe" do
    sign_in_as Platform::User.find_by!(platform_id: 1), password: "otra"

    assert_text "Correo o contraseña incorrectos"
    assert_no_selector "nav"
  end
end
