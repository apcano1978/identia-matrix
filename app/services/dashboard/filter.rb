# El filtro de la barra de comando: `needs:human OR status:qa_cycle`.
#
# Un parser diminuto y a propósito. Tres claves, unidas por OR, y nada más: una
# expresión que nadie sabe escribir de memoria no la usa nadie, y un DSL general
# aquí sería una gramática que mantener para tres consultas.
#
#   needs:human       los que esperan a una persona
#   status:<etapa>    una de las doce, o `qa_cycle`
#   client:<slug>
#
# Lo que no reconoce lo ignora en vez de fallar. Quien escribe en una barra de
# comando corrige sobre la marcha; un error de sintaxis a media palabra es ruido.
class Dashboard::Filter
  SEPARATOR = /\s+OR\s+|\s*,\s*/i
  TERM = /\A(?<key>needs|status|client):(?<value>[a-z0-9_-]+)\z/i

  # `needs` y `status` tienen vocabulario cerrado, así que un valor fuera de él
  # es una errata y se descarta. `client` no: su vocabulario son datos, y un
  # slug que no existe tiene por respuesta legítima «ninguno».
  VOCABULARIES = {
    "needs" => %w[human],
    "status" => Initiative::STAGES + %w[qa_cycle]
  }.freeze

  Term = Data.define(:key, :value)

  attr_reader :raw, :terms

  def initialize(raw)
    @raw = raw.to_s.strip
    @terms = parse
  end

  def any? = terms.any?

  # Un OR: basta con que un término lo acepte.
  def matches?(initiative, board:)
    return true if terms.empty?

    terms.any? { |term| matches_term?(term, initiative, board) }
  end

  # Lo que se pinta de vuelta en la barra. Sin los términos que no entendió: así
  # se ve en el sitio qué se ha aplicado de verdad.
  def to_s = terms.map { |t| "#{t.key}:#{t.value}" }.join(" OR ")

  private
    def parse
      raw.delete_prefix("filter").strip.split(SEPARATOR).filter_map do |chunk|
        match = TERM.match(chunk.strip)
        next if match.blank?

        term = Term.new(key: match[:key].downcase, value: match[:value].downcase)
        next unless known?(term)

        term
      end
    end

    def known?(term)
      vocabulary = VOCABULARIES[term.key]

      vocabulary.blank? || vocabulary.include?(term.value)
    end

    def matches_term?(term, initiative, board)
      case term.key
      when "needs"
        term.value == "human" && board.awaiting_human.include?(initiative)
      when "status"
        term.value == "qa_cycle" ? board.qa_cycle.include?(initiative)
                                 : initiative.current_stage == term.value
      when "client"
        initiative.platform_client.slug == term.value
      end
    end
end
