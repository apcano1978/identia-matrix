# Retirar un documento de un proyecto.
#
# **Retirar no es borrar, y la diferencia es toda la regla**: el documento sale
# del ámbito de los evolutivos NUEVOS y **sigue resolviendo las citas ya
# emitidas**. Un artefacto publicado hace tres meses que lo cita sigue diciendo
# la verdad, porque el documento sigue ahí. Es la misma forma que `missing_since`
# en la proyección de platform.
#
# `create` y no `destroy` ni `update`: es un acto que ocurre una vez y deja
# constancia —la fecha en la que se retiró—, no la edición de un campo. Y no se
# deshace: un documento superado no vuelve, se sube el que lo supera.
class RetirementsController < ApplicationController
  def create
    project = Project.find_by!(slug: params[:project_slug])
    # DENTRO del proyecto, nunca por id suelto: un `ProjectDocument.find` a secas
    # es la forma más fácil de cruzar la frontera sin darse cuenta.
    document = project.project_documents.find(params[:document_id])
    authorize document, :retire?, policy_class: ProjectDocumentPolicy

    document.update!(retired_at: Time.current)

    redirect_to project_path(project), status: :see_other,
                notice: "#{document.title} retirado. Sale del ámbito de los " \
                        "evolutivos nuevos y las citas que ya lo nombran siguen " \
                        "resolviendo."
  end
end
