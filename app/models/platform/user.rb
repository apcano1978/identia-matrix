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

  # El papel en cada evolutivo. Ver `may_approve?` más abajo.
  #
  # ⚠ Hoy esta tabla está INERTE, y conviene saberlo: solo entran en matrix
  # `admin` y `superadmin`, y los dos son operadores que pueden todo. Empieza a
  # decidir algo cuando F7 traiga la autenticación de verdad y `ROLES_WITH_ACCESS`
  # pueda ensancharse a gente que participa en un evolutivo sin operar el
  # sistema. Se construye ahora porque es donde va la regla, no porque cambie
  # nada todavía.
  #
  # Lo que SÍ decide algo hoy es otra cosa, y no depende de papeles: **nadie
  # autoriza su propia solicitud**.
  has_many :initiative_roles, foreign_key: :platform_user_id,
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

  # ── Qué puede hacer alguien DENTRO de un evolutivo ────────────────────────
  #
  # El rol de acceso dice quién entra; el papel dice qué puede hacer aquí. Son
  # cosas distintas y viven en sitios distintos: `role` lo sincroniza platform,
  # `initiative_roles` es de matrix.
  #
  # `admin` y `superadmin` pueden **todo lo que exige intervención humana**, en
  # cualquier evolutivo y sin necesidad de una fila de papel: son el equipo que
  # opera el sistema. El papel existe para lo otro — dar autoridad a quien no es
  # de ese equipo, y distinguir a quien solo puede levantar la mano.

  # Firmar GATE 1 y validar GATE 2.
  def may_sign?(initiative) = may_approve?(initiative)

  def may_approve?(initiative)
    return false unless may_access_matrix?
    return true if operator?

    role_in(initiative)&.approver? || false
  end

  # Levantar la mano sobre un paso que no se puede recorrer, y recorrer pasos.
  # Basta con estar en el evolutivo, con cualquier papel.
  def may_participate?(initiative)
    return false unless may_access_matrix?

    operator? || role_in(initiative).present?
  end

  # El equipo que opera matrix. Se llama así y no `admin?` porque `admin` es un
  # valor del enum y esto es la pregunta, no el valor.
  def operator? = admin? || superadmin?

  def role_in(initiative)
    return nil if initiative.blank?

    initiative_roles.find { |row| row.initiative_id == initiative.id }
  end

  # Si esta persona puede leer el material de un cliente concreto.
  #
  # Hoy la respuesta es la misma para todos los clientes: quien entra en matrix
  # los ve todos. **El cliente entra por la firma de todos modos**, igual que en
  # `Citations::Resolve`, y por el mismo motivo: el día que haya alcance por
  # cliente —una persona de platform asignada solo a los suyos— hay un único
  # sitio que tocar, y ninguna llamada que revisar.
  def may_read_client?(_client) = may_access_matrix?

  # Lo que se congela en `gate_signatures.identity` al firmar. Sin nombre no se
  # queda en blanco: el correo identifica igual.
  def identity_snapshot
    label = name.presence || email_address
    cargo.present? ? "#{label} · #{cargo}" : label
  end

  def to_s = name.presence || email_address
end
