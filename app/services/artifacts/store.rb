# frozen_string_literal: true

module Artifacts
  # Listar lo que hay en el almacén, sea disco o bucket.
  #
  # Active Storage sabe leer y escribir un objeto que le nombres, pero no
  # enumerar lo que hay: nunca lo necesita, porque siempre parte de una fila. La
  # reconciliación parte justo del otro lado —¿qué objetos hay que nadie
  # reclama?— y por eso necesita esto.
  #
  # Solo dos servicios, y son los dos que matrix usa: Disk en desarrollo y test,
  # S3 en producción. Cualquier otro se declara desconocido en vez de devolver
  # una lista vacía, que se leería como «no hay huérfanos» y sería mentira.
  module Store
    class Unsupported < StandardError; end

    module_function

    def keys(service = ActiveStorage::Blob.service)
      case service
      when ActiveStorage::Service::DiskService then disk_keys(service)
      when ActiveStorage::Service::S3Service then s3_keys(service)
      else
        raise Unsupported,
              "no sé enumerar #{service.class}: la reconciliación necesita " \
              "listar el almacén, y devolver una lista vacía se leería como " \
              "«no hay huérfanos»"
      end
    end

    # El servicio de disco reparte los ficheros en subdirectorios por prefijo
    # de la clave (ab/cd/abcdef…), así que la clave es el basename.
    def disk_keys(service)
      root = Pathname(service.root)
      return [] unless root.exist?

      root.glob("**/*").select(&:file?).map { |path| path.basename.to_s }
    end

    def s3_keys(service)
      service.bucket.objects.map(&:key)
    end
  end
end
