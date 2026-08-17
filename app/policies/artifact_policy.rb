# frozen_string_literal: true

# Quién puede leer los bytes de un artefacto.
#
# P3 · la frontera de cliente se imponía solo en el modelo, y el almacenamiento
# no distinguía nada: quien llegara a una clave leía el artefacto de cualquiera.
# La mitad que de verdad protege es ésta, y no una política de bucket: los
# artefactos se sirven por `rails_storage_proxy` —así lo configura
# `application.rb`— y por tanto el control de acceso ocurre en Rails, no en S3.
class ArtifactPolicy < ApplicationPolicy
  def show?
    return false if user.blank?

    user.may_access_matrix? && user.may_read_client?(record.platform_client)
  end
end
