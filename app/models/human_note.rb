# Lo que una persona escribió. Es fuente de ORIGEN de pleno derecho: una nota
# humana pesa lo mismo que un documento o un acta, y por eso se puede citar
# —[src:note/2026-05-08-ap]— y por eso tiene código propio y estable.
class HumanNote < ApplicationRecord
  belongs_to :initiative
  belongs_to :platform_client, class_name: "Platform::Client"
  belongs_to :author_user, class_name: "Platform::User"

  has_many :escalations, dependent: :nullify
  has_many :citations, as: :target, dependent: :nullify

  # La unicidad se acota AL CLIENTE, no al sistema entero. `Citations::Resolve`
  # ya busca dentro de `platform_client_id`, así que una cita solo tiene que ser
  # inequívoca dentro de su cliente — el invariante 10 impide que cruce esa
  # frontera. El ámbito global era más estricto de lo necesario y no compraba
  # nada: hacía que rechazar una firma en ev-014 por la mañana y autorizar una
  # exención en ev-031 por la tarde reventara, aunque fueran de clientes
  # distintos.
  validates :code, presence: true, uniqueness: { scope: :platform_client_id },
                   format: { with: /\A\d{4}-\d{2}-\d{2}-[a-z0-9]+(?:-[a-z0-9]+)*\z/ }
  validates :body, presence: true

  scope :chronological, -> { order(:created_at) }

  def citation = "[src:note/#{code}]"

  # El código de una nota, compuesto para que SEA CITABLE.
  #
  # La gramática es `note/<YYYY-MM-DD>[-<autor>[-<ordinal>]]`, y el autor son
  # **iniciales**: `[a-z]{2,4}`. Un sufijo aleatorio cabe en el formato de la
  # columna pero **no lo puede parsear la gramática**, así que produciría una
  # nota que nadie puede citar — que es media nota.
  #
  # El ordinal se asigna AL CHOCAR, igual que los slugs de documento y por la
  # misma razón: es automático y no hay nada que nombrar. El 1 no se usa, así
  # que la primera nota del día sigue siendo `2026-08-17-ap` y las citas ya
  # emitidas no cambian de forma.
  #
  # El cliente entra por la FIRMA y no por el evolutivo: la unicidad se acota a
  # él, y quien llama tiene que decir de quién habla. Es la misma disciplina que
  # `Citations::Resolve`.
  def self.code_for(author, client:, on: Date.current)
    base = "#{on.iso8601}-#{initials_for(author)}"
    client_id = client.respond_to?(:id) ? client.id : client

    return base unless taken?(base, client_id)

    (2..).each do |ordinal|
      candidate = "#{base}-#{ordinal}"
      return candidate unless taken?(candidate, client_id)
    end
  end

  def self.taken?(code, client_id)
    exists?(code: code, platform_client_id: client_id)
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
