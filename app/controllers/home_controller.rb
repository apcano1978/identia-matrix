class HomeController < ApplicationController
  # Sin autenticar y solo montada en local — ver el porqué en config/routes.rb.
  allow_unauthenticated_access

  def show
    @checks = EnvironmentCheck.all
  end
end
