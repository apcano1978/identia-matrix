# frozen_string_literal: true

module Gates
  # GATE 2 · confirmas que lo ejecutado sirve. No autorizas nada: eso fue GATE 1.
  #
  # A diferencia de GATE 1, **es reversible por rechazo**, y el rechazo devuelve
  # a NEO subiendo `iteration` **sin consumir ciclo de QA**: no hay ningún ✕, no
  # es un fallo de verificación sino una decisión humana.
  #
  # ── El bloqueo asimétrico ────────────────────────────────────────────────
  #
  # Solo bloquea un paso de **única evidencia** que cubra un criterio
  # **crítico** y esté sin resolver. Los auto-verificados no bloquean por muchos
  # que queden: ya los comprobó SERAPH, y pedir que además los recorra una
  # persona convierte la guía en burocracia. Y los no críticos tampoco, porque
  # con la simplificación de F10 la mayoría de criterios acaban en ⊗ y exigirlos
  # todos haría de cada GATE 2 un trámite de diez casillas — que se sellan sin
  # leer, y encima dan la falsa impresión de que alguien lo miró.
  class Validate
    class Blocked < StandardError; end

    Result = Data.define(:validation, :initiative)

    def self.call(...) = new(...).call

    def initialize(initiative:, guide:, user:, decision:, rejection_note: nil)
      @initiative = initiative
      @guide = guide
      @user = user
      @decision = decision.to_sym
      @rejection_note = rejection_note
    end

    def call
      case @decision
      when :validated then validate!
      when :rejected then reject!
      else raise ArgumentError, "decisión desconocida: #{@decision}"
      end
    end

    private
      def validate!
        # Fresco, no de la asociación cargada: entre que se pintó la pantalla y
        # se pulsó el botón, alguien puede haber recorrido o eximido un paso.
        blocking = @guide.reload.blocking_steps
        if blocking.any?
          raise Blocked,
                "quedan #{blocking.size} pasos de única evidencia sin recorrer " \
                "sobre criterios críticos: #{blocking.map(&:position).join(', ')}"
        end

        validation = record(:validated)
        Pipeline::Advance.call(initiative: @initiative, actor: @user.to_s)

        Result.new(validation: validation, initiative: @initiative.reload)
      end

      def reject!
        if @rejection_note.blank?
          raise ArgumentError, "rechazar exige decir por qué"
        end

        validation = record(:rejected)

        # SIN `verification_report:`, y es la diferencia entera: `SendBack` solo
        # sube `qa_cycles_consumed` cuando el informe que lo motiva tiene algún
        # ✕. Un rechazo humano sube `iteration` y nada más.
        Pipeline::SendBack.call(initiative: @initiative, to: :neo,
                                actor: @user.to_s,
                                summary: @rejection_note.truncate(80))

        Result.new(validation: validation, initiative: @initiative.reload)
      end

      # El `coverage_snapshot` se congela AQUÍ, con lo que la persona tenía
      # delante al decidir. Recalcularlo después diría otra cosa.
      def record(decision)
        GateValidation.create!(
          initiative: @initiative, test_guide: @guide, decision: decision,
          decided_by_user: @user, decided_at: Time.current,
          coverage_snapshot: @guide.reload.coverage,
          rejection_note: @rejection_note)
      end
  end
end
