---
citations:
  - "[src:verify/pricing-svc:run-174#L88]"
  - "[src:code/booking-core:rates.ts#L40@c31d5a8]"
  - "[src:code/owner-web:priceLabel.tsx#L22@2d77b90]"
  - "[src:dod/dod-031#c0]"
events:
  - kind: progress
    message: "Ejecutando la suite de los tres repositorios"
  - kind: tool
    message: "pricing-svc · run-174 · 214 tests · 0 fallos"
  - kind: warning
    message: "c0 no es verificable dentro de un repositorio"
findings:
  - kind: verdict
    reference: c0
    verdict: unsupported
    statement: "Compatibilidad entre servicios: nada lo verifica dentro de un repositorio."
    evidence: null
  - kind: verdict
    reference: c1
    verdict: met
    statement: "rates.ts devuelve el precio resuelto."
    evidence: "[src:code/booking-core:rates.ts#L40@c31d5a8]"
    repository: booking-core
  - kind: verdict
    reference: c3
    verdict: met
    statement: "priceLabel.tsx ya no calcula."
    evidence: "[src:code/owner-web:priceLabel.tsx#L22@2d77b90]"
    repository: owner-web
usage:
  input_tokens: 19700
  output_tokens: 3450
  model_used: chat-default
  latency_ms: 41500
---
# Informe de verificación · {{initiative}}

## ✓ c1 · Precio resuelto

[src:code/booking-core:rates.ts#L40@c31d5a8] · suite verde
[src:verify/pricing-svc:run-174#L88]

## ✓ c3 · La etiqueta no calcula

[src:code/owner-web:priceLabel.tsx#L22@2d77b90]

## ⊗ c0 · Compatibilidad entre servicios

Nada puede verificar esto dentro de un solo repositorio
[src:dod/dod-031#c0]. **No es un fallo**: es un criterio que necesita una
persona. Va a la guía de pruebas.

## Semáforo

pricing-svc verde · booking-core verde · owner-web verde.
