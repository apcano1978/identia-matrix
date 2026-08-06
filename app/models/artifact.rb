# Un artefacto: el documento que produce un agente. INMUTABLE, y su clave
# también.
#
# La inmutabilidad se impone en tres sitios porque hay tres formas de romperla:
# editar una columna, borrar la fila y —la que se olvida— volver a adjuntar
# otros bytes dejando la fila intacta. Las tres están cerradas aquí.
#
# Corregir un artefacto es publicar la versión siguiente, no reescribir esta.
class Artifact < ApplicationRecord
  belongs_to :initiative
  belongs_to :platform_client, class_name: "Platform::Client"
  belongs_to :produced_by_run, class_name: "AgentRun", optional: true

  # Los bytes del markdown. En F1/F2 van a disco local; el bucket es F5.
  has_one_attached :body

  has_many :citations, as: :citable, dependent: :destroy

  enum :kind, Artifacts::Key::KINDS.each_with_index.to_h, prefix: true,
       validate: true

  validates :code, presence: true,
                   uniqueness: { scope: [ :initiative_id, :version ] }
  validates :version, numericality: { greater_than_or_equal_to: 1 }
  validates :storage_key, presence: true, uniqueness: true,
                          format: { with: Artifacts::Key::PATTERN }
  validates :checksum, presence: true

  before_update :refuse_column_changes
  before_destroy :refuse_destruction
  before_save :refuse_body_replacement

  scope :latest_first, -> { order(version: :desc) }

  # `download` devuelve bytes crudos —ASCII-8BIT—, y el cuerpo de un artefacto
  # es markdown en UTF-8: sin esto, la primera tilde revienta el renderizado.
  def body_markdown
    return nil unless body.attached?

    body.download.force_encoding(Encoding::UTF_8)
  end

  def to_s = "#{code} v#{version}"

  private
    # Se permite el guardado que solo adjunta los bytes por primera vez: attach
    # sobre un registro persistido pasa por aquí sin cambiar ninguna columna.
    def refuse_column_changes
      return if changes.except("updated_at").empty?

      raise ActiveRecord::ReadOnlyRecord,
            "un artefacto es inmutable: publica la versión siguiente"
    end

    def refuse_destruction
      raise ActiveRecord::ReadOnlyRecord,
            "un artefacto no se borra: una cita ya emitida tiene que seguir " \
            "resolviendo"
    end

    # La que se olvida. `has_one_attached` deja volver a llamar a `attach` y
    # sustituir los bytes sin tocar la fila — inmutabilidad rota sin que nada
    # en la tabla lo delate.
    def refuse_body_replacement
      return if attachment_changes["body"].blank?
      return if id.blank?
      return unless ActiveStorage::Attachment.exists?(
        record_type: "Artifact", record_id: id, name: "body")

      raise ActiveRecord::ReadOnlyRecord,
            "los bytes de un artefacto no se reemplazan: publica la versión " \
            "siguiente"
    end
end
