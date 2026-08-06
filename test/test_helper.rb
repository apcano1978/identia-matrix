ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require "minitest/mock"

Dir[Rails.root.join("test/support/**/*.rb")].each { |file| require file }

module ActiveSupport
  class TestCase
    # EN MACOS, EN SERIE. El binario precompilado de `pg` para arm64-darwin
    # revienta con un segfault en `connect_start` cuando minitest bifurca —y
    # con `OBJC_DISABLE_INITIALIZE_FORK_SAFETY=YES` no revienta: se cuelga, que
    # es peor porque no deja rastro. Con hilos, igual.
    #
    # No se pierde nada medible: la suite serie tarda menos que el arranque de
    # los once procesos. En Linux —CI— el paralelismo sigue activo.
    #
    #   PARALLEL_WORKERS=4 bin/rails test   fuerza un número concreto
    parallelize(workers: ENV.fetch("PARALLEL_WORKERS") {
      RUBY_PLATFORM.include?("darwin") ? 1 : :number_of_processors
    }.then { |w| w.is_a?(Symbol) ? w : w.to_i })

    fixtures :all
  end
end

module SessionTestHelpers
  # La contraseña es la de `Auth::FakeSource`, no una inventada: si la fuente
  # falsa cambia de convención, estos tests tienen que enterarse.
  def sign_in_as(user, password: Auth::FakeSource::DEFAULT_PASSWORD)
    post session_path, params: { email_address: user.email_address, password: password }
  end

  def sign_out = delete session_path
end

class ActionDispatch::IntegrationTest
  include SessionTestHelpers
end

# En los tests de sistema no hay `post`: hay que pasar por el formulario, que es
# además la única forma de comprobar que el formulario funciona.
module SystemSessionHelpers
  def sign_in_as(user, password: Auth::FakeSource::DEFAULT_PASSWORD)
    visit new_session_path
    fill_in "email_address", with: user.email_address
    fill_in "password", with: password
    click_on "entrar ⏎"

    # Esperar al armazón: `click_on` no espera a la redirección, y un `visit`
    # inmediato después corre sobre la sesión todavía sin establecer.
    page.has_css?("nav", wait: 5)
  end
end

# El `include` va en test/application_system_test_case.rb, no aquí: reabrir esa
# clase antes de que se defina con su superclase real da «superclass mismatch».
