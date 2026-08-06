---
citations:
  - "[src:pkg/pkg-045#deploy]"
  - "[src:dod/dod-031#c0]"
  - "[src:close/close-002#§3]"
  - "[src:note/2026-05-08-ap]"
events:
  - kind: progress
    message: "Redactando el cierre documental"
findings: []
usage:
  input_tokens: 34100
  output_tokens: 4780
  model_used: chat-default
  latency_ms: 29600
---
# Cierre · {{initiative}}

## §1 · Qué se hizo

El precio de festivos pasó a resolverse en `booking-core` y a mostrarse sin
recalcular en `owner-web`, desplegado en tres pasos
[src:pkg/pkg-045#deploy].

## §2 · Qué decidió este evolutivo

La fuente única del precio es la tarifa de reserva. Confirma lo que ya decidió
ev-002 [src:close/close-002#§3]; no lo revierte.

## §3 · Desvíos

El criterio c0 se cerró con recorrido humano y no con test
[src:dod/dod-031#c0], por lo que se anotó en su momento
[src:note/2026-05-08-ap].
