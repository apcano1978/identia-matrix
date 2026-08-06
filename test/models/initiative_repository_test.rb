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

  test "un evolutivo NO puede tocar el repositorio de otro cliente" do
    link = InitiativeRepository.new(
      initiative: build_initiative(client: build_client(slug: "vivla")),
      repository: build_repository(client: build_client(slug: "otro-cliente")))

    assert_not link.valid?
    assert_match "otro cliente", link.errors[:repository].to_sentence
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
