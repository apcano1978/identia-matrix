# La raíz de la aplicación: qué espera a una persona, ahora mismo.
class DashboardController < ApplicationController
  def show
    @board = Dashboard::Board.new(filter: params[:q])
    @events = Event.recent.includes(:initiative, :platform_client).limit(Event::STREAM_SIZE)
  end
end
