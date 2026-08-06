---
citations:
  - "[src:spec/spec-031#§7]"
  - "[src:dod/dod-031#c0]"
  - "[src:close/close-002#§3]"
events:
  - kind: progress
    message: "Revisando spec y DoD contra la memoria del repositorio"
findings:
  - kind: advisory
    reference: "§9"
    statement: "El fuera de alcance está escrito, pero no dice qué pasa si un festivo cae en temporada alta."
  - kind: blocking
    reference: c0
    statement: "El criterio de compatibilidad no declara el orden de despliegue, y sin orden la ventana de convivencia no se puede comprobar."
usage:
  input_tokens: 31500
  output_tokens: 2140
  model_used: chat-default
  latency_ms: 27800
---
# Revisión · {{initiative}}

## Bloqueante · c0 sin orden de despliegue

La ventana de convivencia está descrita [src:spec/spec-031#§7] y el criterio
existe [src:dod/dod-031#c0], pero ninguno de los dos dice **en qué orden** se
despliegan los tres repositorios. Sin ese orden, c0 no es comprobable.

Es del **DoD**, no de la spec: la spec describe bien la ventana. Vuelve a
SERAPH.

## Advertencia · temporada alta

El fuera de alcance no cubre el solape. No bloquea.

## Memoria

Coherente con ev-002 [src:close/close-002#§3].
