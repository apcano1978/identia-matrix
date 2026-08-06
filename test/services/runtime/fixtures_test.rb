require "test_helper"

# Los fixtures son la única cosa que ejercita el parser de citas sobre texto de
# verdad antes de F9. Si dejan de llevar citas reales, el parser llega a F9 sin
# haberse probado nunca contra un documento.
class Runtime::FixturesTest < ActiveSupport::TestCase
  test "hay un fixture por cada etapa que trabaja un agente" do
    expected = Pipeline::STAGE_WORK.values
                                   .map { |w| [ w[:agent], w[:purpose] ] }.uniq.sort

    assert_equal expected, Runtime::Fixture.available
  end

  test "todas las citas del cuerpo parsean contra la gramática de F0" do
    each_fixture do |agent, purpose, _metadata, body|
      _valid, invalid = Citations::Parse.scan(body)

      assert_empty invalid,
                   "#{agent}/#{purpose} lleva citas que el parser rechaza"
    end
  end

  test "y no son de adorno: cada fixture cita algo" do
    each_fixture do |agent, purpose, _metadata, body|
      valid, = Citations::Parse.scan(body)

      assert_predicate valid.size, :positive?,
                       "#{agent}/#{purpose} no cita nada"
    end
  end

  # El contrato lo dice: matrix vuelve a parsear el cuerpo de todos modos, y la
  # lista declarada es un CONTRASTE. Una discrepancia es la señal de que el
  # agente se inventó una referencia — así que los fixtures no la tienen.
  test "lo declarado y lo escrito coinciden" do
    each_fixture do |agent, purpose, metadata, body|
      valid, = Citations::Parse.scan(body)
      written = valid.map(&:raw).uniq.sort

      assert_equal written, metadata.fetch("citations", []).uniq.sort,
                   "#{agent}/#{purpose}: la lista declarada no es lo que el " \
                   "cuerpo cita"
    end
  end

  test "un fixture que no existe lo dice, no devuelve vacío" do
    assert_raises(Runtime::MissingFixture) do
      Runtime::Fixture.read(agent: "tank", purpose: "closure")
    end
  end

  private
    def each_fixture
      Runtime::Fixture.available.each do |agent, purpose|
        metadata, body = Runtime::Fixture.read(agent: agent, purpose: purpose)
        yield agent, purpose, metadata, body
      end
    end
end
