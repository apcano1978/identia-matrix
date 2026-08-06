# El runtime real: `POST /v1/agents/{key}/run` contra identia-brain, con
# `X-Feature` para la atribución de coste y `X-Agent-Token` para el tool-calling
# inverso.
#
# Llega en F9 y hasta entonces no finge. Un stub que devolviera un resultado
# vacío pasaría las validaciones y dejaría creer que la integración está.
module Runtime::Brain
  module_function

  def run(request)
    raise NotImplementedError,
          "el runtime contra brain llega en F9; " \
          "usa MATRIX_AGENT_RUNTIME=fake mientras tanto"
  end
end
