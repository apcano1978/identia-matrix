# Un documento de platform. Es fuente de ORIGEN: lo que citan [src:doc/...].
#
# `body` es nullable a propósito. En platform el cuerpo no está en la tabla:
# vive en versiones de contenido y en adjuntos. Un PDF del que nadie extrajo
# texto es un caso real, y decirlo es más honesto que fingir un cuerpo vacío.
class Platform::Document < Platform::Record
  belongs_to :platform_client, class_name: "Platform::Client"
  belongs_to :platform_project, class_name: "Platform::Project", optional: true

  has_many :initiative_sources, as: :source, dependent: :destroy
  has_many :citations, as: :target, dependent: :nullify

  validates :platform_id, presence: true, uniqueness: true
  # Congelado: va dentro de citas ya emitidas.
  validates :slug, presence: true, uniqueness: true,
                   format: { with: /\A[a-z0-9]+(?:-[a-z0-9]+)*\z/ }
  validates :title, presence: true

  # Un documento sin texto no se puede citar por ancla, y quien lo cite tiene
  # que saberlo antes de intentarlo.
  def citable? = body.present?

  def to_s = title
end
