# Subir documentos a un proyecto (F12).
#
# La primera vez que matrix acepta un fichero. `create` y nada más:
#
# - **Sin `show`**: los bytes no se sirven a nadie. Matrix enseña TEXTO, nunca
#   ficheros —el visor renderiza markdown, la ficha de cliente lista sus
#   documentos sin un solo enlace— y `ArtifactAccess` cierra la puerta del proxy
#   de Active Storage para todo lo que no sea un artefacto. Lo que se lee es el
#   cuerpo extraído.
# - **Sin `destroy`**: en matrix no se borra. Retirar es otra cosa, y está en
#   `RetirementsController`.
#
# Admite VARIOS ficheros a la vez porque la zona de arrastre lo invita, y cuenta
# el resultado: subir cinco y que uno pase de 25 MB no puede dejar la pantalla
# diciendo solo «error».
class ProjectDocumentsController < ApplicationController
  def create
    project = Project.find_by!(slug: params[:project_slug])
    authorize ProjectDocument, :create?

    subida = ProjectDocuments::UploadAll.call(
      project: project, files: params[:files], uploader: Current.user)

    redirect_to project_path(project), status: :see_other,
                **flash_for(subida.count, subida.refusals)
  end

  private
    def flash_for(subidos, rechazos)
      return { alert: "No se ha subido nada: #{rechazos.to_sentence}." } if subidos.zero? && rechazos.any?
      return { alert: "No se ha elegido ningún fichero." } if subidos.zero?

      hechos = "#{pluralize_documents(subidos)} · el texto se extrae en un momento"
      return { notice: "#{hechos}." } if rechazos.empty?

      { notice: "#{hechos}. Sin subir: #{rechazos.to_sentence}." }
    end

    def pluralize_documents(count)
      count == 1 ? "1 documento subido" : "#{count} documentos subidos"
    end
end
