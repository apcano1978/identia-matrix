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

  # Las citas que ESTE artefacto hace.
  has_many :citations, as: :citable, dependent: :destroy

  # Y las que apuntan a él: las de tipo spec/dod/pkg/close que lo nombran por su
  # `code`. Son las dos direcciones de la procedencia y por eso no se llaman
  # igual — confundirlas es exactamente el error que F4 vino a cerrar.
  has_many :inbound_citations, as: :target, class_name: "Citation",
                               dependent: :nullify

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

  # ── Los bytes, y las dos formas de leerlos ─────────────────────────────────
  #
  # Desde F5 lo que se almacena es el DOCUMENTO: el front-matter y, debajo, el
  # cuerpo. Son dos cosas distintas y hay que poder pedir cada una:
  #
  #   document             lo que hay en el bucket, tal cual
  #   body_markdown        solo el cuerpo — lo que el visor renderiza
  #   stored_front_matter  la cabecera leída de los bytes, no de la columna
  #
  # `download` devuelve bytes crudos —ASCII-8BIT—, y el markdown es UTF-8: sin
  # el `force_encoding`, la primera tilde revienta el renderizado.
  def document
    return nil unless body.attached?

    body.download.force_encoding(Encoding::UTF_8)
  end

  # El cuerpo, sin la cabecera.
  #
  # NO parsea a ciegas, y el porqué importa: `FrontMatter.parse` reconoce
  # cualquier bloque `---…---` inicial, no solo el suyo. Sobre un cuerpo que
  # empiece por una regla horizontal se comería la primera sección. Se acepta la
  # cabecera solo si dice ser la de ESTE artefacto.
  #
  # De regalo, un artefacto anterior a F5 —sin cabecera— sigue funcionando: no
  # hace falta migrar nada, los bytes viejos y los nuevos conviven.
  def body_markdown
    raw = document
    return nil if raw.nil?

    attributes, body_only = Artifacts::FrontMatter.parse(raw)
    attributes[:key] == storage_key ? body_only : raw
  end

  # La cabecera tal y como viaja dentro del fichero. Distinta de la columna
  # `front_matter`, que es la que matrix guardó al publicar: compararlas es la
  # mitad del trabajo de `Artifacts::Verify`.
  def stored_front_matter
    raw = document
    return {} if raw.nil?

    Artifacts::FrontMatter.parse(raw).first
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
