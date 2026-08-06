---
citations:
  - "[src:doc/acta-precios#p2]"
  - "[src:code/booking-core:rates.ts#L40@4f2a9c1]"
  - "[src:code/owner-web:priceLabel.tsx#L22@e91b330]"
  - "[src:meet/2026-05-14-festivos-y-tarifa]"
events:
  - kind: progress
    message: "Redactando la especificación"
  - kind: note
    message: "Tres repositorios en ámbito: hay ventana de convivencia"
findings: []
usage:
  input_tokens: 22800
  output_tokens: 5940
  model_used: chat-default
  latency_ms: 38700
---
# Especificación · {{initiative}}

## §1 · Objetivo

Unificar el precio de festivos en una sola fuente
[src:doc/acta-precios#p2].

## §2 · Qué cambia en booking-core

`rates.ts` expone el precio final ya resuelto
[src:code/booking-core:rates.ts#L40@4f2a9c1]. Deja de ser interno.

## §4 · Qué cambia en owner-web

`priceLabel.tsx` deja de calcular y pasa a mostrar
[src:code/owner-web:priceLabel.tsx#L22@e91b330].

## §7 · Ventana de convivencia

Durante el despliegue conviven la versión nueva de `booking-core` y la vieja de
`owner-web`. El contrato tiene que aguantar las dos
[src:meet/2026-05-14-festivos-y-tarifa].

## §9 · Fuera de alcance

El precio de temporada alta. No se toca.
