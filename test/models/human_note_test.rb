# frozen_string_literal: true

require "test_helper"

# P8 · el código de una nota humana.
#
# Hasta el 4 de septiembre de 2026 solo cabía una nota citable por autor y día,
# y la segunda no era «no citable»: era un **500**. `code` se validaba único y
# ningún llamante rescataba el `RecordInvalid`, así que la acción —rechazar una
# firma, autorizar una exención— no se completaba.
#
# Y la colisión era GLOBAL. Con un solo operador, dos acciones el mismo día en
# clientes distintos bastaban para reventar.
class HumanNoteTest < ActiveSupport::TestCase
  include DomainBuilders

  test "la primera nota del dia no lleva ordinal" do
    client = build_client
    author = build_platform_user(name: "Antonio Pérez")

    assert_equal "2026-08-17-ap",
                 HumanNote.code_for(author, client: client, on: Date.new(2026, 8, 17))
  end

  test "la segunda nota del mismo autor y dia recibe ordinal, y no revienta" do
    client = build_client
    author = build_platform_user(name: "Antonio Pérez")
    on = Date.new(2026, 8, 17)

    first = write_note(client, author, on)
    assert_equal "2026-08-17-ap", first.code

    # Esto es lo que antes levantaba RecordInvalid y salía como un 500.
    second = write_note(client, author, on)
    assert_equal "2026-08-17-ap-2", second.code

    third = write_note(client, author, on)
    assert_equal "2026-08-17-ap-3", third.code
  end

  test "el mismo autor y dia en dos clientes distintos no colisiona" do
    author = build_platform_user(name: "Antonio Pérez")
    on = Date.new(2026, 8, 17)

    # El caso que de verdad se daba: rechazar una firma en el cliente de la
    # mañana y autorizar una exención en el de la tarde. La unicidad global lo
    # rompía aunque el invariante 10 impida que una cita cruce esa frontera.
    morning = write_note(build_client, author, on)
    afternoon = write_note(build_client, author, on)

    assert_equal "2026-08-17-ap", morning.code
    assert_equal "2026-08-17-ap", afternoon.code,
                 "la unicidad se acota al cliente: el segundo no tiene por qué llevar ordinal"
  end

  test "el codigo con ordinal sigue siendo citable" do
    client = build_client
    author = build_platform_user(name: "Antonio Pérez")
    on = Date.new(2026, 8, 17)

    write_note(client, author, on)
    note = write_note(client, author, on)

    # Media nota es una nota que nadie puede citar. Esta se parsea, y resuelve
    # contra sí misma.
    reference = Citations::Parse.call!(note.citation)

    assert_equal "note", reference.kind
    assert_equal "2026-08-17", reference.locator
    assert_equal "ap", reference.author
    assert_equal "2", reference.note_slug
    assert_equal note, Citations::Resolve.call(reference, client: client)
  end

  test "dos notas del mismo dia resuelven cada una a la suya" do
    client = build_client
    author = build_platform_user(name: "Antonio Pérez")
    on = Date.new(2026, 8, 17)

    first = write_note(client, author, on)
    second = write_note(client, author, on)

    assert_equal first, resolve("[src:note/2026-08-17-ap]", client)
    assert_equal second, resolve("[src:note/2026-08-17-ap-2]", client)
  end

  private
    def write_note(client, author, on)
      HumanNote.create!(
        initiative: build_initiative(client: client),
        platform_client: client, author_user: author,
        code: HumanNote.code_for(author, client: client, on: on),
        body: "Una nota")
    end

    def resolve(raw, client)
      Citations::Resolve.call(Citations::Parse.call!(raw), client: client)
    end
end
