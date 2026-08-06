# La sesión sí es de matrix —su duración, su cookie— aunque el usuario no lo
# sea. Que platform se caiga impide entrar, pero no echa a quien ya está dentro;
# y deshabilitar a alguien en platform no cierra su sesión aquí: eso lo hace la
# revalidación de F8.
class Session < ApplicationRecord
  belongs_to :platform_user, class_name: "Platform::User"

  # `alias_method` y no `alias_attribute`: desde Rails 7.2 el segundo exige un
  # ATRIBUTO, y `platform_user` es una asociación. Falla al usarse, no al
  # cargarse — por eso sobrevivió a F2 entera, que no tenía login.
  alias_method :user, :platform_user
end
