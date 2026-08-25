require "test_helper"

# De dónde saca matrix el host, el dueño y el nombre. Sin esto no sabe a qué
# API preguntar, y un repositorio cuya URL no se entiende simplemente no se
# puede indexar — su ficha lo dirá, en vez de fingir que sí.
class Repositories::RemoteTest < ActiveSupport::TestCase
  def parse(url) = Repositories::Remote.parse(url)

  test "las dos formas que se usan de verdad dicen lo mismo" do
    ssh = parse("git@github.com:identia/evalora-core.git")
    https = parse("https://github.com/identia/evalora-core")

    assert_equal "github.com", ssh.host
    assert_equal "identia/evalora-core", ssh.slug
    assert_equal ssh.to_h, https.to_h
  end

  test "el .git final es opcional y no forma parte del nombre" do
    assert_equal "evalora-core", parse("git@github.com:identia/evalora-core.git").name
    assert_equal "evalora-core", parse("git@github.com:identia/evalora-core").name
    assert_equal "evalora-core", parse("https://github.com/identia/evalora-core.git").name
  end

  test "un nombre con punto no se recorta por el punto" do
    # `docs.site` es un nombre legítimo: `Repository` lo admite y las rutas
    # llevan una restricción para que Rails no se lo coma como formato.
    assert_equal "docs.site", parse("git@github.com:identia/docs.site").name
    assert_equal "docs.site", parse("git@github.com:identia/docs.site.git").name
  end

  test "el host se normaliza a minúsculas: es la clave del adaptador" do
    assert_equal "github.com", parse("git@GitHub.com:identia/core.git").host
  end

  test "una URL con usuario dentro no confunde al dueño" do
    assert_equal "identia", parse("https://token@github.com/identia/core").owner
  end

  test "otros hosts se entienden igual: la interfaz no es solo de GitHub" do
    ubicacion = parse("git@gitlab.example.com:cliente/servicio.git")

    assert_equal "gitlab.example.com", ubicacion.host
    assert_equal "cliente/servicio", ubicacion.slug
  end

  test "lo que no se entiende devuelve nulo, sin reventar" do
    [ nil, "", "  ", "no-es-una-url", "https://github.com/solo-el-dueno",
      "ftp://github.com/a/b" ].each do |basura|
      assert_nil parse(basura), "#{basura.inspect} debería no entenderse"
    end
  end
end
