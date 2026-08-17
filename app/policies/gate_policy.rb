# frozen_string_literal: true

# Las dos puertas. El `record` es el evolutivo, porque lo que se pregunta no es
# «¿puedes firmar esta firma?» sino «¿puedes firmar EN ESTE EVOLUTIVO?».
#
# Firmar y validar exigen lo mismo: ser operador de matrix, o tener papel de
# `approver` en el evolutivo. Son las dos decisiones nominales del sistema y
# ninguna se delega.
class GatePolicy < ApplicationPolicy
  # GATE 1 · autoriza que se ejecute. Irreversible.
  def sign? = user.present? && user.may_sign?(record)

  # GATE 2 · confirma que lo ejecutado sirve. Reversible por rechazo.
  def validate? = sign?

  # Devolver a TRINITY con nota: la cuarta bifurcación. Quien puede firmar
  # puede negarse a firmar, que es de lo que se trata.
  def send_back? = sign?
end
