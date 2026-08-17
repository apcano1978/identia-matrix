# frozen_string_literal: true

module Guides
  # Marcar un paso de la guía como recorrido.
  #
  # Es un servicio y no un `update!` en el controlador por una razón: deja
  # constancia. En un sistema cuyo producto es evidencia, «alguien lo recorrió»
  # sin decir quién ni cuándo no vale de nada.
  class WalkStep
    Result = Data.define(:step, :coverage)

    def self.call(...) = new(...).call

    def initialize(step:, user:, note: nil)
      @step = step
      @user = user
      @note = note
    end

    def call
      ApplicationRecord.transaction do
        @step.update!(walked_at: Time.current, walked_by_user: @user,
                      walk_note: @note.presence)
        record_event
      end

      Result.new(step: @step, coverage: @step.test_guide.reload.coverage)
    end

    private
      # Solo se anota el paso de ÚNICA EVIDENCIA. Un auto-verificado recorrido a
      # mano es una confirmación amable, no una novedad: SERAPH ya lo comprobó, y
      # llenar el stream con eso taparía lo que sí importa.
      def record_event
        return unless @step.evidence_sole_evidence?

        initiative = @step.test_guide.initiative

        Event.create!(
          occurred_at: Time.current, actor: @user.to_s, kind: "activity",
          initiative: initiative, platform_client: initiative.platform_client,
          message: "GATE 2 · paso #{format('%02d', @step.position)} recorrido · " \
                   "única evidencia de #{criterion_label}")
      end

      def criterion_label
        @step.dod_criterion ? @step.dod_criterion.to_s : "un criterio sin trazar"
      end
  end
end
