# Avanza a la siguiente etapa de las doce. Es la transición aburrida, y es la
# que más veces corre.
class Pipeline::Advance
  include Pipeline::Transition

  Result = Data.define(:initiative, :stage_entry)

  def self.call(...) = new(...).call

  def initialize(initiative:, actor: Pipeline::SYSTEM_ACTOR, summary: nil,
                 metric: nil)
    @initiative = initiative
    @actor = actor
    @summary = summary
    @metric = metric
  end

  # Las dos paradas obligatorias del sistema, impuestas al ENTRAR y no al salir:
  # así ninguna ruta las esquiva, venga de un avance normal o de un reintento.
  #
  #   trinity      invariante 5 · ninguna spec pasa a plan sin revisión de MORFEO
  #   claude_code  invariante 6 · ningún paquete se ejecuta sin firma que lo cubra
  PRECONDITIONS = {
    "trinity" => :reviewed_definition_of_done!,
    "claude_code" => :signature_covering_the_package!
  }.freeze

  def call
    initiative.with_lock do
      from = initiative.current_stage
      to = next_stage
      check_precondition!(to)

      close_current_entry(status: :done)
      entry = enter(to, summary: @summary, metric: @metric)
      refresh_cache(stage: to)
      record_event(kind: "stage_advanced",
                   message: "#{stage_label(to)} · entra",
                   from: from, to: to, iteration: initiative.iteration)

      Result.new(initiative: initiative, stage_entry: entry)
    end
  end

  private
    def next_stage
      position = Initiative::STAGES.index(initiative.current_stage)
      following = Initiative::STAGES[position + 1]

      if following.blank?
        raise Pipeline::InvalidTransition,
              "#{initiative.code} ya está en la última etapa (publication)"
      end

      following
    end

    def check_precondition!(stage)
      guard = PRECONDITIONS[stage]
      send(guard) if guard
    end

    def reviewed_definition_of_done!
      dod = initiative.definitions_of_done.latest_first.first

      return if dod&.reviewed?

      raise Pipeline::PreconditionFailed,
            "#{initiative.code} no puede pasar a plan: el DoD no lo ha " \
            "revisado MORFEO"
    end

    # No basta con que exista una firma: tiene que cubrir el paquete entero. Un
    # multi-repo firmado con dos de sus tres repositorios autoriza a escribir en
    # un sitio sobre el que nadie firmó.
    def signature_covering_the_package!
      signature = initiative.gate_signatures.order(:signed_at).last

      raise Pipeline::PreconditionFailed,
            "#{initiative.code} no puede ejecutarse: GATE 1 sin firmar" \
        if signature.blank?

      return if signature.covers_package?

      raise Pipeline::PreconditionFailed,
            "la firma de #{initiative.code} no cubre todos los repositorios " \
            "del paquete"
    end
end
