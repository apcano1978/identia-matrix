# Las pantallas que cuelgan de un evolutivo.
#
# Todas cargan lo mismo y de la misma forma, y todas tienen que respetar la
# frontera de cliente: se busca el evolutivo DENTRO de su cliente, nunca por su
# código a secas. Un `Initiative.find_by(code:)` suelto es la forma más fácil de
# cruzar la frontera sin darse cuenta.
module InitiativeScoped
  extend ActiveSupport::Concern

  included do
    before_action :load_initiative
    # Las cinco pantallas vuelven al evolutivo desde su barra de vista.
    helper_method :initiative_path_for
  end

  private
    def load_initiative
      @client = Platform::Client.find_by!(slug: params[:client_slug])
      @initiative = @client.initiatives.find_by!(code: params[:initiative_code])
    end

    # El DoD vigente: el de versión más alta. Las anteriores se leen desde el
    # visor de artefactos, que es donde vive la historia.
    def current_dod
      @initiative.definitions_of_done.latest_first.first
    end

    def current_report
      @initiative.verification_reports.chronological.last
    end

    def current_guide
      @initiative.test_guides.order(:id).last
    end

    def initiative_path_for(**options)
      client_initiative_path(@client, @initiative, **options)
    end

    # Turbo Drive exige 303 tras un POST para seguir la redirección con un GET.
    def redirect_after(path, **options)
      redirect_to path, status: :see_other, **options
    end
end
