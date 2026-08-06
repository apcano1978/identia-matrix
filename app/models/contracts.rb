# frozen_string_literal: true

# Los contratos versionados de matrix con sus dos vecinos.
#
#   contracts/matrix-brain/agent_run.v1.json      matrix → brain
#   contracts/matrix-brain/agent_result.v1.json   brain  → matrix
#   contracts/matrix-platform/read.v1.json        platform → matrix
#
# Viven AQUÍ y solo aquí. Los consumidores fijan la versión; no se duplican
# entre repositorios. Ni el brain ni platform declaran hoy versión alguna en sus
# payloads, así que este lado es el único sitio donde la compatibilidad se puede
# comprobar de verdad.
#
#   Contracts.validate!(:matrix_brain_agent_run, payload)
module Contracts
  class ValidationError < StandardError
    attr_reader :contract, :errors

    def initialize(contract, errors)
      @contract = contract
      @errors = errors
      super("el payload no cumple el contrato #{contract}:\n#{errors.join("\n")}")
    end
  end

  ROOT = Rails.root.join("contracts")

  PATHS = {
    matrix_brain_agent_run: "matrix-brain/agent_run.v1.json",
    matrix_brain_agent_result: "matrix-brain/agent_result.v1.json",
    matrix_platform_read: "matrix-platform/read.v1.json"
  }.freeze

  module_function

  def names = PATHS.keys

  def path(name) = ROOT.join(PATHS.fetch(name))

  # El esquema crudo, tal cual está en disco.
  def definition(name)
    @definitions ||= {}
    @definitions[name] ||= JSON.parse(path(name).read)
  end

  def schema(name)
    @schemas ||= {}
    @schemas[name] ||= JSONSchemer.schema(definition(name))
  end

  def valid?(name, payload) = schema(name).valid?(deep_stringify(payload))

  # Los errores en formato legible, uno por línea, con su puntero JSON.
  def errors(name, payload)
    schema(name).validate(deep_stringify(payload)).map do |error|
      pointer = error["data_pointer"].presence || "(raíz)"
      "#{pointer}: #{error['error']}"
    end
  end

  def validate!(name, payload)
    found = errors(name, payload)
    raise ValidationError.new(name, found) if found.any?

    payload
  end

  # Las claves de un payload de Ruby llegan como símbolos; JSON Schema valida
  # sobre cadenas.
  def deep_stringify(value)
    case value
    when Hash  then value.to_h { |k, v| [ k.to_s, deep_stringify(v) ] }
    when Array then value.map { |item| deep_stringify(item) }
    else value
    end
  end

  # Solo para tests: fuerza la relectura desde disco.
  def reset_cache!
    @definitions = nil
    @schemas = nil
  end
end
