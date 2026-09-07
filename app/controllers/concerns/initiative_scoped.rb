# Las pantallas que cuelgan de un evolutivo.
#
# Todas cargan lo mismo y de la misma forma, y todas tienen que respetar la
# frontera de PROYECTO: se busca el evolutivo DENTRO de su proyecto, nunca por su
# nombre a secas. Un `Initiative.find_by(slug:)` suelto es la forma más fácil de
# cruzar la frontera sin darse cuenta — y aquí es donde de verdad se defiende,
# porque las policies solo comprueban acceso a la aplicación, no ámbito.
module InitiativeScoped
  extend ActiveSupport::Concern

  included do
    before_action :load_initiative
    # Las cinco pantallas vuelven al evolutivo desde su barra de vista.
    helper_method :initiative_path_for
  end

  private
    def load_initiative
      @project = Project.find_by!(slug: params[:project_slug])
      @initiative = @project.initiatives.find_by!(slug: params[:initiative_slug])
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
      project_initiative_path(@project, @initiative, **options)
    end

    # Turbo Drive exige 303 tras un POST para seguir la redirección con un GET.
    def redirect_after(path, **options)
      redirect_to path, status: :see_other, **options
    end
end
