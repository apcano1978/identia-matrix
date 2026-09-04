# frozen_string_literal: true

module Guides
  # Autorizar que un paso se cierre SIN la prueba que nadie pudo hacer.
  #
  # Es el otro extremo de `RaiseHand`, y hacen falta **dos personas**: quien
  # está bloqueado levanta la mano, y alguien con autoridad —y que no sea esa
  # misma persona— decide. Lo comprueba `GuideStepPolicy#authorize_exemption?`.
  #
  # ── Eximido no es recorrido, y se guarda distinto ────────────────────────
  #
  # Marcar `walked_at` sería más barato. Pero entonces la cobertura diría «4 de
  # 4 pasos recorridos» cuando dos no lo están, y LINK no tendría cómo
  # distinguirlos al narrar el desvío en el cierre. En un sistema cuyo producto
  # es evidencia honesta, una pantalla que miente cuesta más que una columna.
  #
  # Por eso la autorización deja una `HumanNote` de **nivel ORIGEN**: es lo que
  # LINK citará, y una decisión humana no puede ser derivada de nada.
  class AuthorizeExemption
    class Refused < StandardError; end

    Result = Data.define(:step, :escalation, :human_note)

    def self.call(...) = new(...).call

    def initialize(step:, user:, reason:)
      @step = step
      @user = user
      @reason = reason
    end

    def call
      raise Refused, "hace falta dejar por escrito por qué se cierra sin esa prueba" if @reason.blank?

      # Por el scope y no por la asociación cargada: quien levanta la mano y
      # quien autoriza son dos personas y, en un test, dos llamadas seguidas
      # sobre el mismo objeto en memoria.
      escalation = @step.opened_escalations.open.order(:id).last
      raise Refused, "nadie ha levantado la mano sobre este paso" if escalation.blank?
      raise Refused, "nadie autoriza su propia solicitud" if escalation.opened_by_user_id == @user.id

      note = nil

      ApplicationRecord.transaction do
        note = write_note
        exempt!(escalation, note)
        resolve!(escalation, note)
      end

      # Reanudar el pipeline va fuera: el evolutivo estaba detenido en la
      # escalada y vuelve a GATE 2, que es donde estaba trabajando.
      resume(escalation)

      Result.new(step: @step.reload, escalation: escalation.reload,
                 human_note: note)
    end

    private
      def initiative = @step.test_guide.initiative

      # Nivel ORIGEN, como la nota de reinicio tras escalada: es una afirmación
      # de una persona, no algo derivado por el sistema.
      def write_note
        HumanNote.create!(
          initiative: initiative,
          platform_client: initiative.platform_client,
          author_user: @user,
          code: HumanNote.code_for(@user, client: initiative.platform_client),
          body: "Autorizado cerrar el paso #{format('%02d', @step.position)} " \
                "sin recorrerlo: #{@reason}")
      end

      # Las tres columnas van juntas: `GuideStep` valida que una eximición sin
      # quién la autorizó o sin la escalada que la respalda no se puede guardar.
      def exempt!(escalation, _note)
        @step.update!(exempted_at: Time.current, exempted_by_user: @user,
                      escalation: escalation)
      end

      def resolve!(escalation, note)
        escalation.update!(resolved_at: Time.current, resolved_by_user: @user,
                           human_note: note)
      end

      # Vuelve a GATE 2 en la misma iteración: no es un salto hacia atrás, es
      # retomar lo que estaba en marcha. `Pipeline::Restart` no sirve aquí —se
      # niega expresamente para este motivo— porque subiría `iteration` y
      # resetearía los ciclos de QA, y aquí no ha fallado ninguna verificación.
      def resume(escalation)
        initiative.with_lock do
          entry = initiative.stage_entries
                            .where(stage: :gate_2, iteration: initiative.iteration)
                            .order(:id).last
          entry&.update!(status: :active, exited_at: nil)
          initiative.update!(current_stage: :gate_2, current_stage_status: :active,
                             stage_changed_at: Time.current)
        end

        Event.create!(
          occurred_at: Time.current, actor: @user.to_s, kind: "activity",
          initiative: initiative, platform_client: initiative.platform_client,
          message: "GATE 2 · paso #{format('%02d', @step.position)} eximido · " \
                   "autorizado por #{@user}")
        escalation
      end
  end
end
