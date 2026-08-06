require "test_helper"

class Dashboard::BoardTest < ActiveSupport::TestCase
  setup { DesignSeed.call }

  test "las cinco bandejas reparten los ocho evolutivos vivos, sin solaparse" do
    board = Dashboard::Board.new
    codes = board.trays.flat_map { |tray| tray.rows.map { |r| r.initiative.code } }

    assert_equal 8, codes.size
    assert_equal codes.uniq, codes
    assert_equal Initiative.open.pluck(:code).sort, codes.sort
  end

  test "estan en el orden en el que le piden algo al humano" do
    assert_equal %w[ESPERAN\ FIRMA ESPERAN\ VALIDACIÓN ESPERAN\ APROBACIÓN
                    CICLO\ QA EN\ CURSO],
                 Dashboard::Board.new.trays.map(&:title)
  end

  # La maqueta mete ev-024 en «ciclo QA» contradiciendo su propio texto: un `?`
  # no consume ciclo, y el evolutivo está detenido esperando a una persona.
  test "un evolutivo escalado espera a un humano, no esta en ciclo QA" do
    board = Dashboard::Board.new
    ev_024 = Initiative.find_by!(code: "ev-024")

    assert_includes board.halted, ev_024
    assert_includes board.awaiting_human, ev_024
    assert_not_includes board.qa_cycle, ev_024
  end

  test "el resumen cuenta lo mismo que las bandejas" do
    board = Dashboard::Board.new
    summary = board.summary

    assert_equal 8, summary.active
    assert_equal board.awaiting_human.size, summary.awaiting_human
    assert_equal summary.active,
                 summary.in_progress + summary.qa_cycle + summary.awaiting_human
  end

  # El detalle de la fila depende de qué la tiene parada: la firma quiere saber
  # qué paquete, la validación cuántos pasos van, y el ciclo qué falló.
  test "cada bandeja dice lo suyo en la primera linea" do
    headlines = Dashboard::Board.new.trays.to_h do |tray|
      [ tray.key, tray.rows.to_h { |r| [ r.initiative.code, r.headline ] } ]
    end

    assert_equal "pkg-031 · 14 tareas · 2 migraciones",
                 headlines[:awaiting_signature]["ev-041"]
    assert_equal "guia-pruebas-031 · 2/4 pasos",
                 headlines[:awaiting_validation]["ev-031"]
    assert_match "inconclusive environment", headlines[:halted]["ev-024"]
  end

  test "la segunda linea es cliente/repo @sha anclado" do
    row = Dashboard::Board.new.awaiting_signature
                          .then { |list| Dashboard::Board.new.trays.first.rows.first }

    assert_equal [ "caser/triaje-core @a02f781" ], row.sources
  end

  test "la edad sale de la marca del nodo activo, no de la apertura" do
    assert_in_delta 3.days.ago, Initiative.find_by!(code: "ev-041").stage_changed_at,
                    5.minutes
    assert_in_delta 25.minutes.ago, Initiative.find_by!(code: "ev-038").stage_changed_at,
                    5.minutes
  end
end
