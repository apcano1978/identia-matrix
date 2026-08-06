# Base de las cinco tablas que son proyección de identia-platform.
#
# La regla es el invariante 1: matrix no modifica ningún origen. Aquí se impone
# en el modelo y no en el controlador, porque el sitio por donde se colaría una
# escritura no es un formulario —no habrá ninguno— sino un `update` incidental
# dentro de un job o de una consola.
#
# La única forma de escribir es abrir la ventana explícitamente:
#
#   Platform::Record.writing { client.update!(name: "Nuevo") }
#
# que es lo que hacen `Platform::FakeSource` (F2) y `Platform::Sync` (F8). El
# nombre es incómodo a propósito: quien lo escribe está declarando que actúa
# como sincronización, no como aplicación.
class Platform::Record < ApplicationRecord
  self.abstract_class = true

  # Por hilo: un job de sincronización no puede abrir la ventana para el resto
  # de la aplicación.
  thread_mattr_accessor :sync_window, instance_accessor: false

  class << self
    def writing
      previous = Platform::Record.sync_window
      Platform::Record.sync_window = true
      yield
    ensure
      Platform::Record.sync_window = previous
    end

    def syncing? = Platform::Record.sync_window.present?
  end

  def readonly? = !self.class.syncing?

  # Ni siquiera la sincronización borra. Lo que desaparece del origen se marca
  # con `missing_since`, porque una cita ya emitida tiene que seguir resolviendo
  # dentro de un artefacto que nadie puede reescribir.
  def destroy
    raise ActiveRecord::ReadOnlyRecord,
          "la proyección de platform no se borra: usa missing_since"
  end
  alias_method :destroy!, :destroy

  # Presente en el origen la última vez que se miró.
  scope :present_in_platform, -> { where(missing_since: nil) }
  scope :missing_in_platform, -> { where.not(missing_since: nil) }

  def missing_in_platform? = missing_since.present?
end
