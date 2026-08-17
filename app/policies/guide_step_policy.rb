# frozen_string_literal: true

# Un paso de la guía de pruebas.
class GuideStepPolicy < ApplicationPolicy
  # Recorrer un paso: basta con participar en el evolutivo. Recorrer es
  # trabajo, no autoridad.
  def walk? = user.present? && user.may_participate?(initiative)

  # Levantar la mano sobre un paso que no se puede recorrer. Lo mismo: quien
  # está bloqueado es quien lo dice.
  def raise_hand? = walk?

  # Autorizar que se cierre SIN esa prueba. Esto sí es autoridad.
  #
  # Y la regla que de verdad protege, que no depende de ningún papel: **nadie
  # autoriza su propia solicitud**. Un bloqueo que se cierra solo no es un
  # control, es un trámite — y la fase entera existe para que la evidencia sea
  # honesta.
  def authorize_exemption?
    return false unless user.present? && user.may_approve?(initiative)

    escalation = record.opened_escalations.open.order(:id).last
    return false if escalation.blank?

    escalation.opened_by_user_id != user.id
  end

  private
    def initiative = record.test_guide.initiative
end
