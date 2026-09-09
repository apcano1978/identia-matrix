# frozen_string_literal: true

module Sources
  # Volver a decidir qué fuentes entran en un evolutivo (F12 · B5).
  #
  # El alta las decide una vez; esto las vuelve a decidir. Es lo que el rediseño
  # promete al pie del alcance —*«se puede ampliar más tarde»*— y lo que evita
  # que recortar sea una puerta de un solo sentido: alguien que acota de más
  # deja al agente sin material y no tendría forma de arreglarlo.
  #
  # ── Aplica la MISMA regla que el alta, y eso no es casualidad ─────────────
  #
  #   queda alguna ofrecida sin marcar  →  se sella: las filas SON el ámbito
  #   están todas marcadas              →  se DESSELLA: vuelve a heredarlo todo
  #
  # La segunda rama es la que hace reversible el recorte. Marcarlo todo no es
  # «acotar a todo»: es decir que no hay recorte, y entonces el evolutivo vuelve
  # a recibir también lo que se suba mañana. Cualquier otra lectura dejaría un
  # evolutivo congelado para siempre por haber tocado la pantalla una vez.
  #
  # `Sources::Scope.offered` es quien dice qué se ofreció, y por eso está allí:
  # si el alta y esto no contestaran lo mismo, la pantalla prometería un ámbito
  # distinto del que se guarda.
  #
  # ── Diferencia, no reescribe ──────────────────────────────────────────────
  #
  # Las filas que siguen se quedan como están. No es una optimización: cada fila
  # lleva `refs_count` —cuántas veces se referencia esa fuente en el corpus
  # indexado— y ese número no se puede recomputar desde aquí. Borrar y recrear lo
  # pondría a cero, y el «7 refs» de la pantalla pasaría a ser mentira.
  class Rescope
    Refused = Class.new(StandardError)

    def self.call(...) = new(...).call

    def initialize(initiative:, sources:)
      @initiative = initiative
      @sources = Array(sources).uniq
    end

    def call
      validate!

      Initiative.transaction do
        narrowed? ? seal : unseal
        initiative
      end
    end

    private

    attr_reader :initiative, :sources

    # INVARIANTE 10 otra vez: lo que llega del formulario se compara contra la
    # lista legal, y de ahí no se sale. Lo ya acotado cuenta como legal aunque
    # hoy no esté disponible —un documento acotado y luego retirado sigue siendo
    # del ámbito de este evolutivo— porque quitárselo sin pedirlo sería cambiar
    # el ámbito por la espalda.
    def validate!
      intrusos = sources - legal
      return if intrusos.empty?

      raise Refused, "esas fuentes no son de #{initiative.project.slug}: " \
                     "#{intrusos.map(&:slug).join(', ')}"
    end

    def narrowed?
      Scope.narrowed?(sources, Scope.offered(initiative.project, plus: current))
    end

    def legal
      @legal ||= (Scope.available_for(initiative.project).values.flat_map(&:sources) +
                  current).uniq
    end

    def current = @current ||= initiative.initiative_sources.map(&:source)

    def seal
      sobran = initiative.initiative_sources.reject { |row| sources.include?(row.source) }
      sobran.each(&:destroy!)

      (sources - current).each do |source|
        initiative.initiative_sources.create!(source: source)
      end

      initiative.update!(sources_scoped_at: Time.current)
    end

    # Sin recorte no hacen falta filas: la ausencia de fecha ES la herencia, y
    # dejar las filas ahí haría que la pantalla enseñara un ámbito que ya no
    # gobierna nada.
    def unseal
      initiative.initiative_sources.destroy_all
      initiative.update!(sources_scoped_at: nil)
    end
  end
end
