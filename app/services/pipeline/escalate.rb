# Detiene el flujo y abre una escalada. Solo lo reinicia una persona, con nota.
#
# Escalar NO es fallar. La etapa queda `escalated` y no `failed` porque el
# glifo, el historial y la bandeja del dashboard tienen que poder distinguir
# «esto salió mal» de «esto necesita que alguien decida».
class Pipeline::Escalate
  include Pipeline::Transition

  Result = Data.define(:initiative, :escalation)

  def self.call(...) = new(...).call

  def initialize(initiative:, reason:, actor: Pipeline::SYSTEM_ACTOR,
                 opened_by_user: nil, verification_report: nil,
                 guide_step: nil, message: nil)
    @initiative = initiative
    @reason = reason.to_s
    @actor = actor
    @opened_by_user = opened_by_user
    @verification_report = verification_report
    @guide_step = guide_step
    @message = message
  end

  def call
    initiative.with_lock do
      escalation = Escalation.create!(
        initiative: initiative,
        platform_client_id: initiative.platform_client_id,
        reason: @reason, opened_at: Time.current,
        opened_by_user: @opened_by_user,
        opened_by_verification: @verification_report,
        guide_step: @guide_step)

      close_current_entry(status: :escalated)
      refresh_cache(stage: initiative.current_stage, status: :escalated)
      record_event(kind: "escalated",
                   message: @message || default_message,
                   reason: @reason, stage: initiative.current_stage,
                   iteration: initiative.iteration)

      Result.new(initiative: initiative, escalation: escalation)
    end
  end

  private
    def default_message
      "#{stage_label(initiative.current_stage)} · detenido · #{@reason}"
    end
end
