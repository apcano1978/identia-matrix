# Una decisión del acta: una pregunta, su respuesta y en qué quedó.
#
# Es lo que el ARQUITECTO produce en la etapa 1. Tres estados y ninguno más:
#
#   abierta      se preguntó y no hay respuesta. No impide avanzar, se arrastra.
#   cerrada      se decidió, y la respuesta es lo que la spec da por cierto.
#   descartada   se preguntó y quedó fuera de alcance. NO es lo mismo que cerrada,
#                y por eso es un estado y no una decisión cerrada con respuesta
#                «no»: descartar es acotar el trabajo, cerrar es definirlo.
class Decision < ApplicationRecord
  belongs_to :initiative
  # La frontera, desnormalizada. Ver la migración: el invariante 10 se defiende
  # con un `where` sobre una clave foránea, no navegando asociaciones.
  belongs_to :project
  belongs_to :raised_by_run, class_name: "AgentRun", optional: true

  # ⚠ POSICIONAL, como `AgentRun#agent` y `Citation#source_kind`: es una columna
  # entera. Lo que venga después se ANEXA; intercalar cambiaría el significado de
  # las filas ya escritas sin tocarlas.
  enum :status, { open: 0, closed: 1, discarded: 2 }, prefix: true, validate: true

  # El estado, en el idioma del ANCLA de la cita. El enum va en inglés como los
  # otros cinco del sistema; la gramática habla español porque la interfaz habla
  # español, y `Citations::Grammar::DECISION_ANCHOR` fija estas tres palabras.
  ANCHORS = { "open" => "abierta", "closed" => "cerrada",
              "discarded" => "descartada" }.freeze

  validates :ordinal, presence: true,
                      numericality: { only_integer: true, greater_than: 0 },
                      uniqueness: { scope: :initiative_id }
  validates :question, presence: true

  scope :by_ordinal, -> { order(:ordinal) }
  scope :pending, -> { where(status: :open) }

  before_update :refuse_change_after_publication

  # `abierta-4`. El ordinal es global dentro del evolutivo; el estado es el que
  # tenía cuando se publicó el acta.
  def anchor = "#{ANCHORS.fetch(status)}-#{ordinal}"

  # La cita que la nombra dentro del acta de su evolutivo.
  def citation(code) = "[src:acta/#{code}##{anchor}]"

  def answered? = answer.present?

  # El acta publicada de este evolutivo, si la hay. Es lo que cierra la ventana
  # de edición.
  def published_acta
    initiative.artifacts.kind_acta.order(version: :desc).first
  end

  private
    # ── LA VENTANA DE MUTABILIDAD ───────────────────────────────────────────
    #
    # Una decisión se corrige mientras el acta se está escribiendo, y deja de
    # poderse corregir en cuanto el acta se publica. **La razón no es que el acta
    # sea inmutable —que lo es—: es que de ella salen la spec y los deltas.**
    #
    # Cambiar una decisión después dejaría la spec escrita contra unos requisitos
    # que ya no existen, y nada lo diría: la spec no se regenera sola y el
    # artefacto que la contiene no se puede anotar. Un cambio posterior no es una
    # corrección del acta, es OTRO DELTA.
    #
    # Consecuencia: una devolución a `need` —que `SendBack#validate_destination!`
    # permite— **no reabre el acta**. Quien necesite requisitos distintos abre
    # otro delta, que es donde ese cambio se puede razonar y fechar.
    def refuse_change_after_publication
      acta = published_acta
      return if acta.blank?

      raise ActiveRecord::ReadOnlyRecord,
            "el acta #{acta.code} ya está publicada: de ella salen la spec y " \
            "los deltas, así que un cambio posterior es otro delta, no una " \
            "corrección de esta decisión"
    end
end
