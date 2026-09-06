require "test_helper"

# INVARIANTE 10 · la frontera de cliente es dura, y es del modelo.
class InitiativeRepositoryTest < ActiveSupport::TestCase
  test "un evolutivo cruza un repositorio de su propio cliente" do
    client = build_client
    link = InitiativeRepository.new(
      initiative: build_initiative(client: client),
      repository: build_repository(client: client))

    assert_predicate link, :valid?
  end

  test "un evolutivo NO puede tocar el repositorio de otro proyecto" do
    link = InitiativeRepository.new(
      initiative: build_initiative(client: build_client(slug: "vivla")),
      repository: build_repository(client: build_client(slug: "otro-cliente")))

    assert_not link.valid?
    assert_match "otro proyecto", link.errors[:repository].to_sentence
  end

  # F11 · LA FRONTERA SE ESTRECHÓ, y esto es lo que lo demuestra: hasta ahora
  # dos proyectos del mismo cliente podían prestarse repositorios, porque la
  # comprobación era por cliente. Ya no.
  #
  # Lo que era legal sigue siéndolo —dos clientes nunca comparten proyecto—, así
  # que la migración no pudo invalidar nada ya escrito. Solo se prohíbe algo que
  # antes pasaba inadvertido.
  test "ni el de otro proyecto del MISMO cliente" do
    cliente = build_client(slug: "vivla")
    otro = Project.create!(platform_client: cliente, slug: "vivla-segundo",
                           name: "El segundo de vivla", opened_at: Time.current)

    link = InitiativeRepository.new(
      initiative: build_initiative(client: cliente),
      repository: build_repository(project: otro, name: "booking-core"))

    assert_not link.valid?
    assert_match "otro proyecto", link.errors[:repository].to_sentence
  end

  test "el mismo repositorio no se cruza dos veces" do
    client = build_client
    initiative = build_initiative(client: client)
    repository = build_repository(client: client)
    InitiativeRepository.create!(initiative: initiative, repository: repository)

    duplicate = InitiativeRepository.new(initiative: initiative,
                                         repository: repository)

    assert_not duplicate.valid?
  end
end
