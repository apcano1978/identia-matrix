# frozen_string_literal: true

# Quién puede subir un documento a un proyecto y quién puede retirarlo. Mismo
# criterio que las tres altas anteriores: quien entra en matrix trabaja en
# matrix.
#
# **No hay `show?`, y no es un olvido.** Los bytes del fichero no se sirven a
# nadie: matrix enseña TEXTO, nunca ficheros — el visor renderiza markdown y la
# ficha de cliente lista sus documentos sin un solo enlace. `ArtifactAccess`
# cierra la puerta del proxy de Active Storage para todo lo que no sea un
# artefacto, y eso incluye estos. Una policy de lectura aquí sugeriría que hay
# algo que leer por ahí.
#
# Tampoco hay `update?` ni `destroy?`: retirar es marcar, no editar ni borrar, y
# no se deshace.
class ProjectDocumentPolicy < ApplicationPolicy
  def create? = user&.may_access_matrix? || false

  def retire? = create?
end
