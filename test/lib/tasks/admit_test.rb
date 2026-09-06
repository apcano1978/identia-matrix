require "test_helper"
require "rake"

# `matrix:admit` es la única puerta por la que entra en matrix un cliente sin
# trabajo en marcha, así que lo que se prueba son sus guardas: que el motivo sea
# obligatorio, que no se admita dos veces al mismo, y que un id que platform no
# reconoce no deje una admisión huérfana apuntando a nadie.
class AdmitTest < ActiveSupport::TestCase
  include DomainBuilders

  def setup
    load_rake_tasks_once
    %w[matrix:admit matrix:leads matrix:admissions].each { |t| Rake::Task[t].reenable }
    ENV["MATRIX_PLATFORM_SOURCE"] = "platform"
  end

  def teardown = ENV.delete("MATRIX_PLATFORM_SOURCE")

  # La tarea aborta con `abort`, que es un SystemExit con el mensaje en stderr.
  def admitir(platform_id, reason, leads: [])
    fuente = Struct.new(:filas) do
      def clients = filas
      def users = []
      def projects = []
      def documents = []
      def meetings = []
      def name = "platform"
      def lead_catalog = filas.map { |f| f.merge(has_work: false) }
    end.new(leads)

    salida = nil
    error = nil
    Platform::Source.stub(:current, ->(*, **) { fuente }) do
      salida = capture_io do
        Rake::Task["matrix:admit"].invoke(platform_id, reason)
      end.first
    rescue SystemExit => e
      error = e.message
    end
    [ salida, error ]
  end

  test "sin motivo no admite" do
    # Es lo único que distingue una excepción de una puerta abierta.
    _, error = admitir(57, "")

    assert_match(/Falta el motivo/, error.to_s)
    assert_equal 0, ClientAdmission.count
  end

  test "admite al lead que platform reconoce y lo deja proyectado" do
    salida, error = admitir(57, "preparando el evolutivo",
                            leads: [ { platform_id: 57, name: "Acme Retail", archived: false } ])

    assert_nil error, salida
    assert_equal [ 57 ], ClientAdmission.pluck(:platform_id)
    assert_equal "preparando el evolutivo", ClientAdmission.first.reason
    assert_not_nil Platform::Client.find_by(platform_id: 57)
    assert_match(/su documentación ya está en matrix/, salida)
  end

  test "no admite dos veces al mismo cliente" do
    ClientAdmission.create!(platform_id: 57, reason: "ya estaba", admitted_by: "antonio")

    _, error = admitir(57, "otra vez")

    assert_match(/Ya estaba admitido/, error.to_s)
    assert_equal 1, ClientAdmission.count
  end

  test "un id que platform no reconoce se dice, no se traga" do
    # Sin esto quedaría una admisión apuntando a nadie, y el síntoma sería que
    # el cliente «no aparece» sin que nada explique por qué.
    _, error = admitir(999, "id equivocado", leads: [])

    assert_match(/no devolvió ningún lead con id 999/, error.to_s)
  end

  test "con la fuente falsa se niega: la maqueta no tiene leads que admitir" do
    ENV["MATRIX_PLATFORM_SOURCE"] = "fake"

    _, error = admitir(57, "preparando")

    assert_match(/MATRIX_PLATFORM_SOURCE es `fake`/, error.to_s)
    assert_equal 0, ClientAdmission.count
  end
end
