require "test_helper"

# Cerrar el acta. Es un solo acto con dos efectos —publicar y salir de la etapa
# 1— y esa unión es la decisión que este test protege.
class Actas::CloseTest < ActiveSupport::TestCase
  setup do
    @initiative = build_initiative
    place(@initiative, :need)
    @author = build_platform_user
    Actas::Turn.call(initiative: @initiative, message: "Adelante.",
                     author: @author)
  end

  test "publica el acta por el único camino que hay" do
    resultado = close

    assert_predicate resultado.artifact, :kind_acta?
    assert_equal "arquitecto-#{format('%03d', @initiative.number)}",
                 resultado.artifact.code
    assert_equal 1, resultado.artifact.version
    assert resultado.artifact.storage_key.end_with?("/v1.md")
  end

  test "y sale de la etapa 1, porque cerrar los requisitos ES terminarla" do
    close

    assert_predicate @initiative.reload, :at_tank?
    assert_predicate @initiative, :status_active?
  end

  # El arrastre queda escrito donde alguien lo va a leer dentro de dos meses:
  # con cuántas preguntas sin contestar se decidió seguir.
  test "el resumen de la etapa dice cuántas quedaron abiertas" do
    entrada = close_and_find_entry

    assert_match "acta cerrada", entrada.summary
    assert_match "1 abiertas que se arrastran", entrada.summary
  end

  test "y si no queda ninguna, no lo menciona" do
    @initiative.decisions.pending.find_each do |decision|
      decision.update!(status: :closed, answer: "Resuelta.")
    end

    entrada = close_and_find_entry

    assert_match "acta cerrada · 3 decididas", entrada.summary
    assert_no_match(/arrastran/, entrada.summary)
  end

  # LA DECISIÓN DEL BLOQUE: se puede cerrar con decisiones abiertas.
  #
  # La maqueta pone al ARQUITECTO diciendo que no puede, y manda la guía: una
  # decisión abierta no impide avanzar, se arrastra. Bloquear el cierre dejaría
  # ese arrastre sin un solo caso que lo estrene.
  test "se cierra con decisiones abiertas, que es de lo que va el arrastre" do
    assert_predicate @initiative.decisions.pending, :any?

    resultado = close

    assert_equal 1, resultado.open_count
    assert_predicate @initiative.reload, :at_tank?
  end

  # Publicada el acta, las decisiones quedan congeladas SOLAS: la guarda del
  # modelo mira si existe el artefacto, y ahora existe. Nadie tuvo que acordarse.
  test "y al cerrar, las decisiones quedan congeladas sin que nadie las toque" do
    close
    abierta = @initiative.decisions.pending.first

    assert_raises(ActiveRecord::ReadOnlyRecord) do
      abierta.update!(status: :closed, answer: "Tarde.")
    end
  end

  # ── Las dos negativas ─────────────────────────────────────────────────────

  # Sin esta guarda, `Artifacts::Publish#next_version_for` cuenta las que hay y
  # sigue: un segundo cierre publicaría una v2 en silencio, que es lo correcto
  # para un artefacto que se corrige y no para uno que se cierra.
  test "cerrar dos veces no publica una segunda versión" do
    close

    error = assert_raises(Actas::Close::Refused) { close }

    assert_match "ya está cerrada", error.message
    assert_equal 1, @initiative.artifacts.kind_acta.count
  end

  test "un acta sin decisiones no cierra nada" do
    otro = build_initiative
    place(otro, :need)

    error = assert_raises(Actas::Close::Refused) do
      Actas::Close.call(initiative: otro, actor: "antonio")
    end

    assert_match "no hay ninguna decisión", error.message
    assert_predicate otro.reload, :at_need?
  end

  private
    def close = Actas::Close.call(initiative: @initiative, actor: "antonio")

    def close_and_find_entry
      close
      @initiative.stage_entries.find_by!(stage: :need)
    end
end
