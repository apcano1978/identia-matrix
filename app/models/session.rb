# La sesión sí es de matrix —su duración, su cookie— aunque el usuario no lo
# sea. Que platform se caiga impide entrar, pero no echa a quien ya está dentro;
# y deshabilitar a alguien en platform no cierra su sesión aquí: eso lo hace la
# revalidación de F8.
class Session < ApplicationRecord
  belongs_to :platform_user, class_name: "Platform::User"

  alias_attribute :user, :platform_user
end
