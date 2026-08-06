# Un usuario de identia-platform, proyectado. Matrix no tiene usuarios propios
# ni guarda contraseñas: el login va contra platform (F2 §1.7, F7).
#
# La POLÍTICA de acceso sí es de matrix y vive aquí: solo entran `admin` y
# `superadmin`, y un usuario deshabilitado no entra. La fuente autentica; matrix
# decide.
class Platform::User < Platform::Record
  ROLES_WITH_ACCESS = %w[admin superadmin].freeze

  has_many :sessions, foreign_key: :platform_user_id,
                      inverse_of: :platform_user, dependent: :destroy

  enum :role, { admin: 0, superadmin: 1, marketing: 2 }, validate: true

  normalizes :email_address, with: ->(e) { e.to_s.strip.downcase }

  validates :email_address, presence: true, uniqueness: true
  validates :platform_id, presence: true, uniqueness: true

  # Las tres condiciones, las mismas que `may_access_matrix?`. Cuando el scope y
  # el predicado no coinciden, una pantalla acaba listando a alguien que no
  # puede entrar.
  scope :with_access, lambda {
    where(role: ROLES_WITH_ACCESS, disabled: false, missing_since: nil)
  }

  # Lo que decide si esta persona puede entrar en matrix. Tres condiciones, y
  # las tres se comprueban aquí para que no haya una segunda respuesta en otro
  # sitio que pueda discrepar.
  def may_access_matrix?
    ROLES_WITH_ACCESS.include?(role) && !disabled? && !missing_in_platform?
  end

  # Lo que se congela en `gate_signatures.identity` al firmar. Sin nombre no se
  # queda en blanco: el correo identifica igual.
  def identity_snapshot
    label = name.presence || email_address
    cargo.present? ? "#{label} · #{cargo}" : label
  end

  def to_s = name.presence || email_address
end
