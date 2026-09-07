# El acta del ARQUITECTO: qué se decidió en la etapa 1, y qué sigue abierto.
#
# Solo lectura. La conversación que la llena —los turnos y el cierre— llega en
# B9; aquí se lee lo decidido, que es lo que MORFEO levanta como advertencia y
# LINK recupera al cerrar.
#
# ⚠ El nombre del controlador no es negociable: `ShellHelper::RAIL_SECTIONS`
# mapea `"actas" => :projects` comparando contra `controller_name`, y con
# cualquier otro nombre el rail se apagaría al entrar aquí.
class ActasController < ApplicationController
  include InitiativeScoped

  # `TODAS` no filtra; las otras dos sí. `descartada` cuenta como cerrada en el
  # titular —está decidida— pero tiene pestaña propia dentro de CERRADAS, que es
  # como lo pinta el rediseño: lo que separa la vista es «decidido» de «pendiente».
  TABS = { "cerradas" => %i[closed discarded], "abiertas" => %i[open] }.freeze

  def show
    @decisions = @initiative.decisions.by_ordinal.includes(:raised_by_run).to_a
    return redirect_after(initiative_path_for, alert: no_acta) if @decisions.empty?

    @tab = TABS.key?(params[:tab]) ? params[:tab] : "todas"
    @visible = filtered(@decisions)
    @open_count = @decisions.count(&:status_open?)
    @closed_count = @decisions.size - @open_count
    @acta = @initiative.artifacts.kind_acta.order(version: :desc).first
    @runs = @initiative.agent_runs.where(agent: :arquitecto).chronological.to_a
  end

  private
    def no_acta
      "#{@initiative.title} todavía no tiene acta: la escribe el ARQUITECTO en " \
        "la etapa de necesidad, preguntando hasta cerrar cada decisión."
    end

    def filtered(decisions)
      states = TABS[@tab]
      return decisions if states.blank?

      decisions.select { |decision| states.include?(decision.status.to_sym) }
    end
end
