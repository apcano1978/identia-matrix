# frozen_string_literal: true

require "test_helper"

class ContractsTest < ActiveSupport::TestCase
  # Afirma que el payload cumple, y si no, enseña QUÉ campo falla. Un
  # `validate!` a secas pasaría el test sin una sola aserción.
  def assert_valid_contract(name, payload)
    errors = Contracts.errors(name, payload)
    assert_empty errors, "el payload debería cumplir #{name}:\n#{errors.join("\n")}"
  end

  # --- Los esquemas en sí ---------------------------------------------------

  test "los tres contratos existen, parsean y declaran draft 2020-12" do
    assert_equal %i[matrix_brain_agent_run matrix_brain_agent_result matrix_platform_read],
                 Contracts.names

    Contracts.names.each do |name|
      definition = Contracts.definition(name)

      assert_equal "https://json-schema.org/draft/2020-12/schema", definition["$schema"], name
      assert definition["$id"].present?, "#{name} debe declarar $id"
      assert definition["title"].present?, "#{name} debe declarar title"
      assert_nothing_raised { Contracts.schema(name) }
    end
  end

  test "el $id lleva la version en el nombre del fichero" do
    Contracts.names.each do |name|
      assert_match(/\.v\d+\.json\z/, Contracts::PATHS.fetch(name), name)
      assert_match(/\.v\d+\.json\z/, Contracts.definition(name)["$id"], name)
    end
  end

  # --- matrix → brain · petición de ejecución -------------------------------

  def agent_run_payload(context: {}, config: {})
    {
      contract_version: 1,
      config: { model: "chat-default" }.merge(config),
      context: {
        client: { slug: "vivla", platform_id: 42 },
        initiative: { code: "ev-031", title: "Unificar precios y calendario" },
        stage: "neo",
        qa_cycle: 1
      }.merge(context)
    }
  end

  test "una peticion minima de ejecucion valida" do
    assert_valid_contract(:matrix_brain_agent_run, agent_run_payload)
  end

  test "la peticion admite el evolutivo multi-repo completo" do
    payload = agent_run_payload(context: {
      repositories: [
        { name: "booking-core", pinned_sha: "4f2a9c1", indexed_files_count: 3412 },
        { name: "owner-web",    pinned_sha: "e91b330", indexed_files_count: 1880 },
        { name: "pricing-svc",  pinned_sha: "b7c0d21", indexed_files_count: 640 }
      ],
      sources: [
        { kind: "document", platform_id: 901, title: "acta-precios.pdf" },
        { kind: "meeting",  platform_id: 55,  title: "unificación de precio", occurred_on: "2026-05-02" }
      ],
      prior_artifacts: [
        { key: "artifacts://vivla/ev-002/close-002/v2.md", kind: "close", code: "close-002",
          version: 2, initiative_code: "ev-002", body: "## Cierre documental" }
      ],
      human_notes: [
        { code: "2026-05-08-ap", body: "Techo de dieciséis copropietarios.", author: "antonio.perez" }
      ]
    })

    assert_valid_contract(:matrix_brain_agent_run, payload)
  end

  test "la peticion exige la frontera de cliente" do
    payload = agent_run_payload
    payload[:context].delete(:client)

    refute Contracts.valid?(:matrix_brain_agent_run, payload)
  end

  test "la peticion rechaza un codigo de evolutivo que no sea ev-nnn" do
    payload = agent_run_payload(context: { initiative: { code: "proj-2291", title: "x" } })

    refute Contracts.valid?(:matrix_brain_agent_run, payload)
  end

  test "la peticion rechaza una etapa que no esta en las doce" do
    payload = agent_run_payload(context: { stage: "revision" })

    refute Contracts.valid?(:matrix_brain_agent_run, payload)
  end

  test "la peticion rechaza mas de dos ciclos de QA" do
    refute Contracts.valid?(:matrix_brain_agent_run, agent_run_payload(context: { qa_cycle: 3 }))
  end

  test "la peticion rechaza claves de contexto no declaradas" do
    # El brain descarta en silencio lo que no reconoce. Este contrato existe
    # justo para que ese descarte se detecte aquí y no en producción.
    payload = agent_run_payload(context: { presupuesto: 1000 })

    refute Contracts.valid?(:matrix_brain_agent_run, payload)
  end

  # --- brain → matrix · resultado -------------------------------------------

  def agent_result_payload(**overrides)
    {
      contract_version: 1,
      agent: "seraph",
      purpose: "verification",
      body: "## Informe de verificación\n\nSin incumplimientos.",
      usage: { input_tokens: 12_000, output_tokens: 3_400, cost_usd: 0.18 }
    }.merge(overrides)
  end

  test "un resultado minimo valida" do
    assert_valid_contract(:matrix_brain_agent_result, agent_result_payload)
  end

  test "el resultado admite los cuatro veredictos y solo esos" do
    %w[met unmet inconclusive unsupported].each do |verdict|
      payload = agent_result_payload(findings: [
        { kind: "verdict", reference: "c5", statement: "Coherencia extremo a extremo.", verdict: verdict }
      ])

      assert Contracts.valid?(:matrix_brain_agent_result, payload), "debería aceptar #{verdict}"
    end

    invented = agent_result_payload(findings: [
      { kind: "verdict", reference: "c5", statement: "x", verdict: "parcial" }
    ])
    refute Contracts.valid?(:matrix_brain_agent_result, invented)
  end

  test "el resultado valida las citas contra la gramatica" do
    ok = agent_result_payload(citations: [
      "[src:code/booking-core:rates.ts#L40@4f2a9c1]",
      "[src:doc/acta-precios#p2]"
    ])
    assert_valid_contract(:matrix_brain_agent_result, ok)

    broken = agent_result_payload(citations: [ "rates.ts#L40" ])
    refute Contracts.valid?(:matrix_brain_agent_result, broken)
  end

  test "el patron de citas del contrato se genera desde la gramatica" do
    # Si esto falla, alguien tocó la gramática y no regeneró el contrato.
    # Se arregla con: bin/rails matrix:sync_contracts
    declarado = Contracts.definition(:matrix_brain_agent_result)
                         .dig("properties", "citations", "items", "pattern")

    assert_equal Citations::Grammar::SCHEMA_PATTERN, declarado,
                 "el contrato y la gramática se han separado · corre bin/rails matrix:sync_contracts"
  end

  test "el contrato y el parser aceptan y rechazan exactamente lo mismo" do
    # Este es el candado de verdad, y va en las DOS direcciones. La versión
    # anterior solo comprobaba que lo que el esquema acepta el parser también lo
    # acepte, y el esquema llevaba el patrón laxo: aceptaba código sin
    # repositorio, tipos inventados y anclas desconocidas.
    formas = CitationCorpus::VALID + CitationCorpus::INVALID.keys

    desacuerdos = formas.filter_map do |raw|
      parser = !Citations::Parse.call(raw).nil?
      schema = Contracts.valid?(:matrix_brain_agent_result, agent_result_payload(citations: [ raw ]))

      "#{raw} · parser:#{parser} esquema:#{schema}" if parser != schema
    end

    assert_empty desacuerdos, <<~MSG
      El contrato y el parser no coinciden. Cada desacuerdo es una puerta por la
      que un agente puede colar una referencia que no identifica nada:

      #{desacuerdos.join("\n")}
    MSG
  end

  test "el resultado exige el consumo de tokens" do
    payload = agent_result_payload
    payload.delete(:usage)

    refute Contracts.valid?(:matrix_brain_agent_result, payload)
  end

  test "el resultado rechaza un agente que no es de los seis" do
    refute Contracts.valid?(:matrix_brain_agent_result, agent_result_payload(agent: "pepper"))
  end

  # --- platform → matrix · lectura ------------------------------------------

  test "un indice de clientes valida" do
    payload = {
      leads: [
        { platform_id: 42, name: "Vivla", sector: "proptech", city: "Madrid",
          primary_contact: { name: "marta.roldan", role: "cto" } }
      ]
    }

    assert_valid_contract(:matrix_platform_read, payload)
  end

  test "un proyecto de platform exige ref y cliente aplanado" do
    ok = { projects: [ { platform_id: 2291, ref: "PRJ-2026-9001", name: "Unificar precios", client_platform_id: 42 } ] }
    assert_valid_contract(:matrix_platform_read, ok)

    # La cadena Lead → Budget → BudgetVersion → Project no la replica matrix:
    # platform tiene que exponer el cliente ya resuelto.
    without_client = { projects: [ { platform_id: 2291, ref: "PRJ-2026-9001", name: "x" } ] }
    refute Contracts.valid?(:matrix_platform_read, without_client)
  end

  test "una ref de proyecto con otro formato se rechaza" do
    payload = { projects: [ { platform_id: 2291, ref: "proj-2291", name: "x", client_platform_id: 42 } ] }

    refute Contracts.valid?(:matrix_platform_read, payload)
  end

  test "documentos y transcripciones admiten cuerpo nulo" do
    # Hoy en platform el cuerpo no está en tabla: vive en content_versions y en
    # adjuntos. Un documento sin texto extraído es un caso real, no un error.
    assert_valid_contract(:matrix_platform_read, {
      client_documents: [
        { platform_id: 901, title: "acta-precios.pdf", client_platform_id: 42, body: nil,
          attachments: [ { filename: "acta-precios.pdf", content_type: "application/pdf", extracted_text: nil } ],
          updated_at: "2026-05-02T08:40:00+02:00" }
      ]
    })

    assert_valid_contract(:matrix_platform_read, {
      meetings: [
        { platform_id: 55, title: "unificación de precio", held_on: "2026-05-02",
          client_platform_id: 42, body: "…", duration_seconds: 4360,
          updated_at: "2026-05-02T23:00:00+02:00" }
      ]
    })
  end

  # --- Manejo de errores ----------------------------------------------------

  test "validate! levanta con los punteros de los campos que fallan" do
    error = assert_raises(Contracts::ValidationError) do
      Contracts.validate!(:matrix_brain_agent_run, { contract_version: 1 })
    end

    assert_equal :matrix_brain_agent_run, error.contract
    assert error.errors.any?
    assert_match(/contrato matrix_brain_agent_run/, error.message)
  end

  test "acepta payloads con claves de simbolo" do
    assert Contracts.valid?(:matrix_brain_agent_result, agent_result_payload)
  end
end
