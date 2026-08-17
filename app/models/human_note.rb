# Lo que una persona escribió. Es fuente de ORIGEN de pleno derecho: una nota
# humana pesa lo mismo que un documento o un acta, y por eso se puede citar
# —[src:note/2026-05-08-ap]— y por eso tiene código propio y estable.
class HumanNote < ApplicationRecord
  belongs_to :initiative
  belongs_to :platform_client, class_name: "Platform::Client"
  belongs_to :author_user, class_name: "Platform::User"

  has_many :escalations, dependent: :nullify
  has_many :citations, as: :target, dependent: :nullify

  validates :code, presence: true, uniqueness: true,
                   format: { with: /\A\d{4}-\d{2}-\d{2}-[a-z0-9]+(?:-[a-z0-9]+)*\z/ }
  validates :body, presence: true

  scope :chronological, -> { order(:created_at) }

  def citation = "[src:note/#{code}]"

  # El código de una nota, compuesto para que SEA CITABLE.
  #
  # La gramática de F0 es `note/<YYYY-MM-DD>[-<autor>]`, y el autor son
  # **iniciales**: `[a-z]{2,4}`. Un sufijo aleatorio cabe en el formato de la
  # columna pero **no lo puede parsear la gramática**, así que produciría una
  # nota que nadie puede citar — que es media nota.
  #
  # ⚠ Consecuencia, y es una limitación real: el código es único, así que **solo
  # cabe una nota citable por autor y día**. Está anotado en `pendientes.md`; si
  # hay que arreglarlo, la enmienda tiene que entrar antes de F9.
  def self.code_for(author, on: Date.current)
    "#{on.iso8601}-#{initials_for(author)}"
  end

  # Entre dos y cuatro letras, que es lo que la gramática admite. Con un solo
  # nombre —«Persona»— las iniciales darían una sola letra y la cita no
  # parsearía, así que se cae a las dos primeras letras del nombre.
  def self.initials_for(author)
    source = author.name.presence ||
             author.email_address.to_s.split("@").first.to_s
    letters = ->(text) { text.to_s.downcase.gsub(/[^a-z]/, "") }

    initials = source.split(/[\s._-]+/).first(4)
                     .filter_map { |part| letters.call(part)[0] }.join

    return initials if initials.length.between?(2, 4)

    letters.call(source)[0, 4].to_s.ljust(2, "x")
  end
end
