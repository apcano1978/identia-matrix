# GATE 1. La firma que autoriza a ejecutar, y es IRREVERSIBLE.
#
# Esa irreversibilidad está en el modelo, no en la interfaz: una firma no se
# edita ni se borra. Si hace falta cambiar lo firmado, se sella otro paquete y
# se firma de nuevo — y el historial conserva las dos.
class GateSignature < ApplicationRecord
  belongs_to :initiative
  belongs_to :work_package
  belongs_to :signed_by_user, class_name: "Platform::User"

  has_many :gate_signature_commits, dependent: :restrict_with_exception

  validates :work_package_id, uniqueness: true
  validates :package_hash, presence: true
  # La identidad CONGELADA al firmar. No es redundante con signed_by_user_id: el
  # usuario es una proyección que puede cambiar de nombre, de rol o desaparecer.
  validates :identity, presence: true
  validates :signed_at, presence: true
  # En primera persona y específica del paquete: lo que se firma es una
  # afirmación concreta, no un «acepto» genérico.
  validates :statement, presence: true
  validate :package_must_declare_its_sequence

  before_update :refuse_modification
  # `prepend` porque `dependent: :restrict_with_exception` también instala un
  # before_destroy, y sin esto ganaría él: la firma quedaría protegida por sus
  # hijos en vez de por sí misma, y borrar los hijos primero la dejaría abierta.
  before_destroy :refuse_modification, prepend: true

  def commits_in_deploy_order = gate_signature_commits.order(:deploy_order)

  # Todos los repositorios del paquete tienen su fila de commit. Sin esto, un
  # paquete de tres repositorios se podría firmar con dos y Claude Code
  # escribiría en el tercero sin autorización.
  def covers_package?
    signed = gate_signature_commits.pluck(:repository_id).to_set
    expected = work_package.work_package_repositories
                           .pluck(:repository_id).to_set

    expected.present? && expected == signed
  end

  # Todo lo firmado ha sido ejecutado y confirmado.
  def fully_executed?
    rows = gate_signature_commits.to_a
    rows.any? && rows.all? { |c| c.executed_sha.present? }
  end

  private
    # Un paquete multi-repo sin orden de despliegue no se puede firmar: durante
    # la ventana conviven dos versiones y el orden es lo que decide si esa
    # convivencia funciona. MORFEO lo marca bloqueante; esto lo impide.
    def package_must_declare_its_sequence
      return if work_package.blank?
      return if work_package.deploy_order_complete?

      errors.add(:work_package,
                 "no declara su orden de despliegue: no se puede firmar")
    end

    def refuse_modification
      raise ActiveRecord::ReadOnlyRecord,
            "GATE 1 es irreversible: una firma no se edita ni se borra"
    end
end
