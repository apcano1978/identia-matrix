# Una cita. Es la unidad de procedencia del sistema: lo que convierte una
# afirmación de un agente en algo comprobable.
#
# Resuelve SIEMPRE contra la fuente, nunca contra un índice — así, el día que el
# índice se rehaga en brain, ninguna cita ya emitida se rompe.
#
# El NIVEL —origen o derivada— no se almacena: se deriva de `source_kind` con
# Citations::Grammar. Un dato derivable que se guarda es un dato que se
# desincroniza.
class Citation < ApplicationRecord
  belongs_to :citable, polymorphic: true
  belongs_to :repository, optional: true
  # La fuente ya resuelta: Repository, Platform::Document, HumanNote…
  belongs_to :target, polymorphic: true, optional: true

  enum :source_kind, Citations::Grammar::KINDS.each_with_index.to_h,
       prefix: :kind, validate: true

  validates :raw, presence: true
  validates :locator, presence: true
  validate :raw_must_parse
  validate :repository_required_for_code_kinds

  scope :origin, -> { where(source_kind: Citations::Grammar::ORIGIN_KINDS) }
  scope :derived, -> { where(source_kind: Citations::Grammar::DERIVED_KINDS) }
  scope :in_order, -> { order(:position, :id) }

  def origin? = Citations::Grammar.origin?(source_kind)
  def derived? = Citations::Grammar.derived?(source_kind)
  def level = Citations::Grammar.level(source_kind)

  # Rellena los campos desde el texto de la cita. La gramática es la única
  # autoridad sobre qué significa cada trozo.
  def self.from_raw(raw, **attributes)
    reference = Citations::Parse.call!(raw)

    new(
      raw: reference.raw,
      source_kind: reference.kind,
      locator: reference.locator,
      fragment: reference.anchor,
      commit_sha: reference.commit_sha,
      **attributes
    )
  end

  # El artefacto que hace esta afirmación, si quien cita es un artefacto. Una
  # cita puede colgar de otras cosas —un criterio, un veredicto— y entonces no
  # hay artefacto que marcar.
  def citable_as_artifact = citable.is_a?(Artifact) ? citable : nil

  def to_s = raw

  private
    def raw_must_parse
      return if raw.blank?
      return if Citations::Parse.call(raw).present?

      errors.add(:raw, "no cumple la gramática de citas de F0")
    end

    # INVARIANTE 4: ninguna afirmación sobre el código sin repositorio. Un
    # [src:code/...] que no diga de qué repositorio habla no es comprobable.
    def repository_required_for_code_kinds
      return if source_kind.blank?
      return unless Citations::Grammar.repository_qualified?(source_kind)
      return if repository_id.present?

      errors.add(:repository,
                 "es obligatorio en una cita de tipo #{source_kind}")
    end
end
