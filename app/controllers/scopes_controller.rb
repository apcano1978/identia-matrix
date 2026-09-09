# Recortar el ámbito documental de un evolutivo (F12 · B5).
#
# **La pantalla de fuentes deja de ser de solo lectura**, y era la última que lo
# prometía. El motivo no es cosmético: el alta decide el ámbito una vez, y sin
# esto quien acotara de más dejaría al agente sin material para siempre. El
# rediseño ya lo decía al pie del alcance —«se puede ampliar más tarde»—.
#
# `create` y no `update`: decidir qué lee un agente es un acto, y se puede tomar
# más de una vez. Lo que escribe está entero en `Sources::Rescope`, incluida la
# razón de que marcarlo todo **desselle** en vez de acotar a todo.
#
# ⚠ Es la única escritura de matrix que BORRA filas, y la lista blanca lleva el
# párrafo que lo justifica: lo que borra es un FILTRO, no historia.
class ScopesController < ApplicationController
  def create
    project = Project.find_by!(slug: params[:project_slug])
    # A través del proyecto, no por slug suelto: la frontera entra por la ruta.
    initiative = project.initiatives.find_by!(slug: params[:initiative_slug])
    authorize initiative, :scope?

    Sources::Rescope.call(initiative: initiative, sources: chosen(project))

    redirect_to project_initiative_sources_path(project, initiative),
                status: :see_other, notice: notice_for(initiative)
  rescue Sources::Rescope::Refused => error
    redirect_to project_initiative_sources_path(project, initiative),
                status: :see_other, alert: "No se ha cambiado el ámbito: #{error.message}."
  end

  private
    # ⚠ Tres consultas ACOTADAS, y el tipo no sale nunca de un parámetro: un
    # `params[:source_type].constantize` habría sido más corto y habría dejado
    # que alguien nombrara cualquier clase del sistema. Es la misma forma que usa
    # el alta, y por lo mismo.
    #
    # Aquí no hay testigo como en el alta: llegar a esta acción YA es hablar de
    # ámbito, así que ningún parámetro significa «ninguna marcada», que es una
    # decisión legítima —el evolutivo se queda sin fuentes— y no un formulario a
    # medias.
    def chosen(project)
      client_id = project.platform_client_id

      project.project_documents.where(id: params[:project_document_ids]).to_a +
        Platform::Document.where(platform_client_id: client_id,
                                 id: params[:platform_document_ids]).to_a +
        Platform::Meeting.where(platform_client_id: client_id,
                                id: params[:meeting_ids]).to_a
    end

    # Los dos estados, dichos con lo que significan. «Guardado» no diría nada:
    # lo que hay que saber es si a partir de ahora entra lo que se suba después.
    def notice_for(initiative)
      unless initiative.sources_scoped?
        return "Ámbito sin recortar: entra todo lo disponible, y también lo que " \
               "se suba después."
      end

      "Ámbito recortado a #{initiative.initiative_sources.count} fuentes. Lo que " \
      "se suba después no entrará solo."
    end
end
