# frozen_string_literal: true

# Engancha la guarda de acceso a los controladores de proxy de Active Storage.
#
# Se hace desde un initializer y no heredando porque esos controladores son de
# Rails: no los escribimos nosotros y no pasan por `ApplicationController`.
#
# `to_prepare` y no `after_initialize`: en desarrollo las clases se recargan, y
# sin esto la guarda desaparecería al primer cambio de código — que es la peor
# forma de tener una protección, porque está puesta hasta que deja de estarlo.
Rails.application.config.to_prepare do
  ActiveStorage::Blobs::ProxyController.include(ArtifactAccess)
  ActiveStorage::Representations::ProxyController.include(ArtifactAccess)
end
