require "test_helper"

class Dashboard::FilterTest < ActiveSupport::TestCase
  setup { DesignSeed.call }

  test "needs:human devuelve los que esperan a una persona" do
    board = Dashboard::Board.new(filter: "needs:human")

    assert_equal %w[ev-019 ev-022 ev-024 ev-031 ev-041], codes(board)
  end

  test "status: filtra por etapa" do
    assert_equal %w[ev-019 ev-041], codes(Dashboard::Board.new(filter: "status:gate_1"))
  end

  test "status:qa_cycle no es una etapa y aun asi funciona" do
    assert_equal %w[ev-014], codes(Dashboard::Board.new(filter: "status:qa_cycle"))
  end

  test "client: acota a un cliente" do
    assert_equal %w[ev-014 ev-027 ev-031], codes(Dashboard::Board.new(filter: "client:vivla"))
  end

  test "los terminos se unen con OR" do
    board = Dashboard::Board.new(filter: "status:gate_1 OR status:qa_cycle")

    assert_equal %w[ev-014 ev-019 ev-041], codes(board)
  end

  test "el prefijo `filter` y las comas tambien valen" do
    assert_equal codes(Dashboard::Board.new(filter: "status:gate_1 OR status:qa_cycle")),
                 codes(Dashboard::Board.new(filter: "filter status:gate_1, status:qa_cycle"))
  end

  # Quien escribe en una barra de comando corrige sobre la marcha: un error de
  # sintaxis a media palabra sería ruido, no ayuda.
  test "lo que no entiende lo ignora en vez de fallar" do
    board = Dashboard::Board.new(filter: "needs:hum")

    assert_empty board.filter.terms
    assert_equal 8, codes(board).size
  end

  test "sin filtro no filtra" do
    assert_equal 8, codes(Dashboard::Board.new).size
    assert_equal 8, codes(Dashboard::Board.new(filter: "  ")).size
  end

  test "el resumen sigue contando el total aunque la pantalla filtre" do
    board = Dashboard::Board.new(filter: "status:gate_1")

    assert_equal 2, board.visible_count
    assert_equal 8, board.summary.active
  end

  private
    def codes(board)
      board.trays.flat_map { |t| t.rows.map { |r| r.initiative.code } }.sort
    end
end
