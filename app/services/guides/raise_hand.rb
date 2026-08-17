# frozen_string_literal: true

module Guides
  # «No puedo recorrer este paso.»
  #
  # A veces no es que falte hacerlo: es que no se puede. No hay entorno, el
  # cliente no da acceso, la prueba exige un dato de producción. Un bloqueo
  # perpetuo ahí no protege nada — empuja a que alguien marque el paso como
  # recorrido sin haberlo hecho, que es el único desenlace peor que no cerrarlo.
  #
  # Levantar la mano NO cierra nada. Abre una escalada con el motivo, y la
  # decisión la toma otra persona. Ver `Guides::AuthorizeExemption`.
  class RaiseHand
    class Refused < StandardError; end

    Result = Data.define(:escalation, :step)

    def self.call(...) = new(...).call

    def initialize(step:, user:, reason:)
      @step = step
      @user = user
      @reason = reason
    end

    def call
      raise Refused, "hace falta decir por qué no se puede recorrer" if @reason.blank?
      raise Refused, "el paso #{@step.position} ya está resuelto" if @step.settled?
      raise Refused, "ya hay una mano levantada sobre este paso" if open_escalation?

      # `Pipeline::Escalate` ya sabe abrir esta escalada: acepta `guide_step:` y
      # `opened_by_user:`, y `Escalation` los exige para `unwalkable_step`.
      # También cierra la etapa como escalada y escribe el evento, así que el
      # evolutivo aparece solo en la bandeja ⊘ ESPERAN APROBACIÓN del dashboard.
      result = Pipeline::Escalate.call(
        initiative: @step.test_guide.initiative,
        reason: :unwalkable_step,
        actor: @user.to_s,
        opened_by_user: @user,
        guide_step: @step,
        message: "paso #{format('%02d', @step.position)} · #{@reason}")

      Result.new(escalation: result.escalation, step: @step)
    end

    private
      # Por el scope, no por la asociación cargada: el paso puede venir de una
      # pantalla pintada hace rato.
      def open_escalation? = @step.opened_escalations.open.exists?
  end
end
