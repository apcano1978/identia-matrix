# La máquina de estados. Objetos planos con `self.call`, sin gema — platform
# tampoco usa ninguna, y las doce etapas de matrix caben en una lista.
#
# Cuatro servicios y un traductor:
#
#   Advance   avanza a la siguiente etapa
#   SendBack  CUALQUIER salto hacia atrás, con destino
#   Escalate  detiene el flujo
#   Restart   reinicio humano con nota
#   Glyph     (etapa, estado) → símbolo
#
# `SendBack` cubre las cinco bifurcaciones hacia atrás en vez de haber un
# servicio por cada una: eran cinco copias de la misma mecánica y cinco sitios
# donde olvidarse de subir `iteration`.
module Pipeline
  # Tope de devoluciones de MORFEO. Igual que el de QA, y por la misma razón:
  # reintentar indefinidamente no converge, escala.
  MAX_MORFEO_RETURNS = 2

  # Quien actúa cuando no es una persona. Va en `events.actor`.
  SYSTEM_ACTOR = "SISTEMA".freeze

  # Qué agente trabaja en cada etapa, y con qué propósito. Las cinco etapas que
  # faltan no son de ningún agente: `need` es humana, `gate_1` y `gate_2` son
  # firmas, `claude_code` pasa fuera de matrix y `publication` es el final.
  #
  # SERAPH aparece dos veces con propósitos distintos, que es justo lo que
  # `agent_runs.purpose` existe para poder decir.
  STAGE_WORK = {
    "tank" => { agent: "tank", purpose: "context" },
    "neo" => { agent: "neo", purpose: "spec" },
    "seraph_dod" => { agent: "seraph", purpose: "dod_pass" },
    "morfeo" => { agent: "morfeo", purpose: "review" },
    "trinity" => { agent: "trinity", purpose: "package" },
    "seraph_verification" => { agent: "seraph", purpose: "verification" },
    "link" => { agent: "link", purpose: "closure" }
  }.freeze

  class Error < StandardError; end
  # Se intenta avanzar desde la última etapa, o saltar hacia adelante con
  # SendBack: las dos son un error de programación, no un estado del dominio.
  class InvalidTransition < Error; end
  # Una etapa a la que no se puede entrar todavía porque falta algo que el
  # sistema exige. No es un error de programación: es el sistema negándose.
  class PreconditionFailed < Error; end
end
