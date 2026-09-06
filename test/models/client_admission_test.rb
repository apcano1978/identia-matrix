require "test_helper"

# La lista de excepciones al catálogo. Lo que se prueba aquí es que sea una
# lista de NOMBRES PROPIOS con motivo escrito, y no una puerta abierta.
class ClientAdmissionTest < ActiveSupport::TestCase
  def admission(**attributes)
    ClientAdmission.new({ platform_id: 43, reason: "preparando el evolutivo",
                          admitted_by: "antonio" }.merge(attributes))
  end

  test "una admisión necesita el id del lead, el motivo y quién la hizo" do
    assert admission.valid?

    assert_not admission(platform_id: nil).valid?
    assert_not admission(reason: "").valid?
    assert_not admission(admitted_by: "").valid?
  end

  test "sin motivo no se admite" do
    # Es lo único que distingue una excepción de un criterio más ancho, y dentro
    # de seis meses lo único que explicará la fila.
    admitida = admission(reason: nil)

    assert_not admitida.valid?
    assert_includes admitida.errors[:reason], "no puede estar en blanco"
  end

  test "no se admite dos veces al mismo cliente" do
    admission.save!

    assert_not admission.valid?
  end

  test "no hay clave foránea: se admite antes de que el cliente exista" do
    # Admitirlo es justo lo que hará que su fila en la proyección exista, así
    # que en ese momento no hay nada a lo que apuntar.
    assert_nothing_raised { admission(platform_id: 999_999).save! }
    assert_nil Platform::Client.find_by(platform_id: 999_999)
  end

  test "los ids llegan como conjunto, listos para ampliar el catálogo" do
    admission(platform_id: 43).save!
    admission(platform_id: 44).save!

    assert_equal Set[43, 44], ClientAdmission.platform_ids
  end
end
