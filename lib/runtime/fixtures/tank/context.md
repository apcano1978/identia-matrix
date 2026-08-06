---
citations:
  - "[src:doc/acta-precios#p2]"
  - "[src:meet/2026-05-02@22:40]"
  - "[src:code/booking-core:rates.ts#L40@4f2a9c1]"
  - "[src:close/close-002#§3]"
events:
  - kind: progress
    message: "Leyendo el ámbito documental del cliente"
  - kind: tool
    message: "Índice de booking-core · 412 ficheros"
  - kind: warning
    message: "owner-web no tiene sha anclado: no se cita código suyo"
findings: []
usage:
  input_tokens: 18400
  output_tokens: 3120
  model_used: chat-default
  latency_ms: 24100
---
# Dossier de contexto · {{initiative}}

**{{title}}** · cliente `{{client}}`

## Qué pide el cliente

El precio mostrado al propietario y el precio de reserva divergen en festivos
[src:doc/acta-precios#p2]. En la reunión del 2 de mayo se acordó que la fuente
única fuera la tarifa de reserva [src:meet/2026-05-02@22:40].

## Dónde vive hoy

El cálculo está duplicado: `booking-core` lo resuelve en el motor de tarifas
[src:code/booking-core:rates.ts#L40@4f2a9c1] y `owner-web` lo vuelve a calcular
para pintarlo.

## Memoria que aplica

El cierre de ev-002 ya decidió no duplicar reglas de precio entre servicios
[src:close/close-002#§3]. Este evolutivo lo confirma, no lo revierte.
