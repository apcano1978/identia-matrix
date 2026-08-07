# La primera escritura de la aplicación.
#
# La FORMA de la ruta es el invariante: lo único que se puede crear es una
# resolución. No hay `update`, no hay `destroy`, y no existe ningún parámetro
# que diga a favor de quién se resuelve. «No hay forma de resolverlo al revés»
# se lee en `bin/rails routes`, sin tener que leer este fichero.
class CitationConflictResolutionsController < ApplicationController
  def create
    conflict = CitationConflict.includes(flagged_artifact: :initiative)
                               .find(params[:citation_conflict_id])
    authorize conflict, :resolve?

    Citations::ResolveConflict.call(conflict: conflict, by: Current.user)

    initiative = conflict.flagged_artifact&.initiative
    # `see_other` y no el 302 por defecto: Turbo Drive exige 303 tras un POST
    # para seguir la redirección con un GET. En este repo no había ni un
    # formulario, así que nadie había topado con ello todavía.
    redirect_back_or_to(initiative_path_for(initiative), status: :see_other)
  end

  private
    def initiative_path_for(initiative)
      return root_path if initiative.blank?

      client_initiative_path(initiative.platform_client, initiative)
    end
end
