# Sacar el texto de un documento subido, en segundo plano.
#
# **En un job y no al subir**, que es lo que la guía de F12 pide: una subida que
# espera a un PDF de doscientas páginas es una subida que falla. El rediseño
# enseña el estado mientras tanto —«extrayendo texto · 8 kB»—, y ese estado solo
# existe si la extracción no ocurre dentro de la petición.
#
# `queue_as :default` y no `:low`: `low` tiene concurrencia 1 y es del latido de
# artefactos, que corre solo y sin nadie mirando. Esto lo está esperando alguien
# delante de una pantalla.
module ProjectDocuments
  class ExtractJob < ApplicationJob
    queue_as :default

    # Si el documento ya no está, no hay nada que extraer. Se descarta en
    # silencio en vez de reintentar contra una fila que no existe.
    discard_on ActiveRecord::RecordNotFound

    def perform(document_id)
      ProjectDocuments::Extract.call(ProjectDocument.find(document_id))
    end
  end
end
