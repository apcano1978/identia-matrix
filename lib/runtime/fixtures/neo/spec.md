---
citations:
  - "[src:doc/acta-precios#p2]"
  - "[src:meet/2026-05-02-unificacion-precio@22:40]"
  - "[src:code/booking-core:rates.ts#L40@4f2a9c1]"
  - "[src:code/booking-core:pricing.ts#L12@4f2a9c1]"
  - "[src:code/booking-core:calendar.ts#L88@4f2a9c1]"
  - "[src:code/booking-core:cache.ts#L120@4f2a9c1]"
  - "[src:code/owner-web:priceLabel.tsx#L22@e91b330]"
  - "[src:code/owner-web:api.ts#L64@e91b330]"
  - "[src:code/pricing-svc:quote.ts#L31@b7c0d21]"
  - "[src:close/close-002#§3]"
  - "[src:verify/owner-web:run-163#L44]"
  - "[src:dod/dod-031#c3]"
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

> Cuarta versión. Reescrita tras el segundo ciclo de QA, que devolvió el
> criterio c3 [src:dod/dod-031#c3] y el informe que lo motivó
> [src:verify/owner-web:run-163#L44].

## §1 · Objetivo

Unificar el precio de festivos en una sola fuente
[src:doc/acta-precios#p2]. La tarifa de reserva es la autoridad y el resto la
consulta [src:meet/2026-05-02-unificacion-precio@22:40].

El calendario no decide precio: eso ya lo dejó escrito ev-002 al cerrarse
[src:close/close-002#§3], y esta especificación no lo revierte.

## §2 · Qué cambia en booking-core

`rates.ts` expone el precio final ya resuelto
[src:code/booking-core:rates.ts#L40@4f2a9c1]. Deja de ser interno.

El recargo de festivo se aplica una sola vez, en
[src:code/booking-core:pricing.ts#L12@4f2a9c1], y el calendario deja de
duplicarlo [src:code/booking-core:calendar.ts#L88@4f2a9c1].

La caché de tarifa se invalida al cambiar el recargo
[src:code/booking-core:cache.ts#L120@4f2a9c1]: sin eso, el precio viejo
sobrevive a la corrección.

## §4 · Qué cambia en owner-web

`priceLabel.tsx` deja de calcular y pasa a mostrar
[src:code/owner-web:priceLabel.tsx#L22@e91b330]. El cliente pide el importe ya
resuelto [src:code/owner-web:api.ts#L64@e91b330].

## §5 · Qué cambia en pricing-svc

`quote.ts` es el único que compone el precio
[src:code/pricing-svc:quote.ts#L31@b7c0d21].

## §7 · Ventana de convivencia

Durante el despliegue conviven la versión nueva de `booking-core` y la vieja de
`owner-web`. El contrato tiene que aguantar las dos.

## §9 · Fuera de alcance

El precio de temporada alta. No se toca.
