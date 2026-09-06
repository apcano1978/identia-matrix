require "test_helper"

class Platform::ClientTest < ActiveSupport::TestCase
  include DomainBuilders

  def build_platform_project(client, **attributes)
    Platform::Record.writing do
      Platform::Project.create!(
        platform_id: 90_000 + rand(9_000), platform_project_ref: "PRJ-#{SecureRandom.hex(4)}",
        name: "Un proyecto", platform_client: client, **attributes)
    end
  end

  test "en preparación es estar admitido y no tener ningún proyecto vivo" do
    client = build_client
    ClientAdmission.create!(platform_id: client.platform_id, reason: "preparando", admitted_by: "antonio")

    assert client.in_preparation?
  end

  test "un cliente con trabajo no está en preparación aunque haya sido admitido" do
    # La admisión sobra en cuanto el proyecto aparece; la marca tiene que dejar
    # de salir sola, sin que nadie borre nada.
    client = build_client
    ClientAdmission.create!(platform_id: client.platform_id, reason: "preparando", admitted_by: "antonio")
    build_platform_project(client)

    assert_not client.reload.in_preparation?
  end

  test "un cliente sin admisión nunca está en preparación" do
    # Sin esta condición, «sin proyectos vivos» describiría también al cliente
    # que terminó el suyo — que es otro caso, y lo cuenta `missing_since`.
    assert_not build_client.in_preparation?
  end

  test "un proyecto ausente en platform no cuenta como trabajo vivo" do
    client = build_client
    ClientAdmission.create!(platform_id: client.platform_id, reason: "preparando", admitted_by: "antonio")
    build_platform_project(client, missing_since: Time.current)

    assert client.reload.in_preparation?
  end

  test "los ids admitidos se pueden pasar ya resueltos, sin consultar por fila" do
    client = build_client

    assert client.in_preparation?(Set[client.platform_id])
    assert_not client.in_preparation?(Set[])
  end
end
