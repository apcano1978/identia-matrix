require "test_helper"

# El contador de códigos. Lo que se prueba aquí no es que cuente: es que **no
# recicle**, que es la razón de que esto sea una tabla y no un `max(code) + 1`.
class MatrixSequenceTest < ActiveSupport::TestCase
  include DomainBuilders

  test "reparte números consecutivos, sin repetir" do
    codigos = 5.times.map { Matrix::Sequence.next_initiative_code }

    assert_equal codigos.uniq, codigos
    assert_equal codigos.sort, codigos
  end

  test "el formato casa con lo que valida Initiative" do
    codigo = Matrix::Sequence.next_initiative_code

    assert_match(/\Aev-\d{3,}\z/, codigo)
    assert Initiative.new(code: codigo, title: "x", opened_at: Time.current,
                          platform_client: build_client).valid?
  end

  test "un número NO se recicla cuando se borra su evolutivo" do
    # Es la propiedad entera. `ev-031` está dentro de claves de artefacto
    # inmutables y de citas ya emitidas; si el contador se derivara de la tabla,
    # borrar una fila devolvería su número al reparto y el evolutivo nuevo
    # heredaría las citas del viejo.
    client = build_client
    primero = Initiatives::Open.call(client: client, title: "Uno", actor: "test",
                                     repositories: [ build_repository(client: client) ])
    codigo_liberado = primero.code
    primero.destroy!

    siguiente = Matrix::Sequence.next_initiative_code

    assert_not_equal codigo_liberado, siguiente,
                     "el contador se derivó de la tabla y reutilizó un número"
  end

  test "el contador no baja aunque la tabla se vacíe" do
    3.times { Matrix::Sequence.next_initiative_code }
    Initiative.destroy_all

    assert_equal "ev-004", Matrix::Sequence.next_initiative_code,
                 "el contador sobrevive a las filas; esa es toda su razón de ser"
  end

  test "dos secuencias no se estorban" do
    # Cada una con su propia llave de lock: `pkg` y `ev` no tienen por qué
    # esperarse.
    Matrix::Sequence.next_initiative_code
    paquete = Matrix::Sequence.next_package_code

    assert_equal "pkg-001", paquete
    assert_not_equal Matrix::Sequence.lock_key(MatrixSequence::INITIATIVE),
                     Matrix::Sequence.lock_key(MatrixSequence::PACKAGE)
  end

  test "la llave del lock es estable entre procesos" do
    # `String#hash` NO sirve: Ruby lo aleatoriza en cada arranque, así que dos
    # servidores usarían llaves distintas y el lock no bloquearía nada. Este
    # test fija el valor para que sustituirlo por algo aleatorio se vea.
    assert_equal Matrix::Sequence.lock_key("initiative"),
                 Digest::SHA256.hexdigest("initiative").to_i(16) % (2**62)
  end

  private

  def build_repository(client:, name: "repo-#{SecureRandom.hex(3)}")
    Repository.create!(platform_client: client, name: name, default_branch: "main")
  end
end
