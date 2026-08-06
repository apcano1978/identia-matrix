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
  def sign_in_as(user, password: "password")
    post session_path, params: { email_address: user.email_address, password: password }
  end

  def sign_out = delete session_path
end

class ActionDispatch::IntegrationTest
  include SessionTestHelpers
end
