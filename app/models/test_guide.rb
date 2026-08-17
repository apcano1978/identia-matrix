# La guía de pruebas manuales. Existe SOLO si el informe de verificación dio
# conforme: un evolutivo no puede estar a la vez devuelto a NEO y esperando
# validación humana. Es el invariante 11, impuesto por la asociación
# obligatoria y por la validación de abajo.
class TestGuide < ApplicationRecord
  belongs_to :initiative
  belongs_to :verification_report
  belongs_to :artifact, optional: true

  has_many :guide_steps, dependent: :destroy
  has_many :gate_validations, dependent: :restrict_with_exception

  validates :code, presence: true, uniqueness: true
  validate :verification_report_must_be_conforme

  def steps_in_order = guide_steps.order(:position)

  # La cobertura que GATE 2 enseña. Un paso EXIMIDO no es un paso RECORRIDO:
  # contarlos juntos diría «4 de 4 recorridos» cuando dos no lo están, y LINK no
  # podría narrarlo como desvío.
  def coverage
    steps = guide_steps.to_a
    {
      total: steps.size,
      walked: steps.count(&:walked?),
      exempted: steps.count(&:exempted?),
      pending: steps.count { |s| !s.walked? && !s.exempted? }
    }
  end

  # Lo que impide validar · EL BLOQUEO ASIMÉTRICO (F6 §5).
  #
  # Tres condiciones a la vez, y quitar cualquiera de ellas rompe el diseño:
  #
  #   única evidencia   un auto-verificado ya lo comprobó SERAPH. Pedir que
  #                     además lo recorra una persona es burocracia
  #   crítico           con la simplificación de F10 la mayoría de criterios
  #                     acaban en ⊗; exigirlos todos haría de cada GATE 2 un
  #                     trámite de diez casillas, y los trámites se sellan sin
  #                     leer — peor que no bloquear, porque además parece que
  #                     alguien lo miró
  #   sin resolver      ni recorrido ni eximido
  #
  # Hasta F6 esto no miraba `evidence_origin`, así que un auto-verificado
  # crítico bloqueaba. Lo destapó el primer test que separó los dos casos.
  def blocking_steps
    guide_steps.to_a.select do |step|
      step.evidence_sole_evidence? && step.critical? && !step.settled?
    end
  end

  def to_s = code

  private
    def verification_report_must_be_conforme
      return if verification_report.blank?
      return if verification_report.outcome_conforme?

      errors.add(:verification_report,
                 "no dio conforme: no puede haber guía de pruebas sobre un " \
                 "informe devuelto o escalado")
    end
end
