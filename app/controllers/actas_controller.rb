# El acta del ARQUITECTO: qué se decidió en la etapa 1, y qué sigue abierto.
#
# Desde B9 es también donde se habla con él. La pantalla tiene dos mitades y las
# dos hacen falta: a la izquierda lo decidido, a la derecha la conversación que
# lo decide. Sin la primera, contestar sería hablar a ciegas; sin la segunda, el
# acta sería un documento que nadie puede escribir.
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

  # ⚠ NO redirige cuando no hay decisiones, y en B8 sí lo hacía.
  #
  # Un acta vacía era una pantalla sin nada que enseñar mientras nadie podía
  # escribirla. Ahora es justo donde hay que empezar: un evolutivo recién abierto
  # entra aquí con la lista en blanco y el formulario esperando.
  def show
    @decisions = @initiative.decisions.by_ordinal.includes(:raised_by_run).to_a
    @tab = TABS.key?(params[:tab]) ? params[:tab] : "todas"
    @visible = filtered(@decisions)
    @open_count = @decisions.count(&:status_open?)
    @closed_count = @decisions.size - @open_count
    @acta = @initiative.artifacts.kind_acta.order(version: :desc).first
    @runs = @initiative.agent_runs.where(agent: :arquitecto).chronological.to_a

    # La mitad de la persona en el diálogo. La otra mitad es la lista de
    # decisiones: la respuesta del ARQUITECTO no es prosa, así que no se guarda
    # como prosa — no hay tabla de chat, y no hace falta.
    @notes = @initiative.human_notes.chronological.includes(:author_user).to_a
  end

  private
    def filtered(decisions)
      states = TABS[@tab]
      return decisions if states.blank?

      decisions.select { |decision| states.include?(decision.status.to_sym) }
    end
end
