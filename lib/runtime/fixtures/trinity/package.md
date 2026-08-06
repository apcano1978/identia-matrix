---
citations:
  - "[src:dod/dod-031#c0]"
  - "[src:code/booking-core:rates.ts#L40@4f2a9c1]"
  - "[src:code/owner-web:priceLabel.tsx#L22@e91b330]"
  - "[src:code/pricing-svc:quote.ts#L31@a04e6c2]"
events:
  - kind: progress
    message: "Componiendo el paquete de trabajo"
  - kind: note
    message: "Tres repositorios, secuencia obligatoria"
findings:
  - kind: deploy_step
    reference: "1"
    statement: "pricing-svc · expone la regla de festivos"
    repository: pricing-svc
  - kind: deploy_step
    reference: "2"
    statement: "booking-core · consume la regla y expone el precio resuelto"
    repository: booking-core
  - kind: deploy_step
    reference: "3"
    statement: "owner-web · deja de calcular"
    repository: owner-web
usage:
  input_tokens: 26900
  output_tokens: 4310
  model_used: chat-default
  latency_ms: 33200
---
# Paquete de trabajo · {{initiative}}

## Secuencia de despliegue

1. **pricing-svc** — la regla de festivos
   [src:code/pricing-svc:quote.ts#L31@a04e6c2]
2. **booking-core** — el precio resuelto
   [src:code/booking-core:rates.ts#L40@4f2a9c1]
3. **owner-web** — la etiqueta
   [src:code/owner-web:priceLabel.tsx#L22@e91b330]

El orden importa: invertir 2 y 3 deja a `owner-web` mostrando un precio que
`booking-core` todavía no resuelve [src:dod/dod-031#c0].

## Tareas

19 tareas, 4 ficheros nuevos, 11 modificados, 1 migración.
