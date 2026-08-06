---
citations:
  - "[src:spec/spec-031#§2]"
  - "[src:spec/spec-031#§4]"
  - "[src:spec/spec-031#§7]"
  - "[src:spec/spec-031#§9]"
events:
  - kind: progress
    message: "Derivando criterios de la especificación"
  - kind: warning
    message: "Evolutivo multi-repo: se añade el criterio c0 obligatorio"
findings:
  - kind: criterion
    reference: c0
    statement: "La versión nueva de booking-core y la vieja de owner-web conviven sin romper el contrato de precio."
    repository: null
  - kind: criterion
    reference: c1
    statement: "rates.ts devuelve el precio final resuelto para una fecha festiva."
    repository: booking-core
  - kind: criterion
    reference: c3
    statement: "priceLabel.tsx muestra el precio recibido sin recalcularlo."
    repository: owner-web
usage:
  input_tokens: 14200
  output_tokens: 2880
  model_used: chat-default
  latency_ms: 19300
---
# Definición de terminado · {{initiative}}

## c0 · Compatibilidad entre servicios · *obligatorio*

Durante la ventana de despliegue, la versión nueva de `booking-core` y la vieja
de `owner-web` conviven sin romper el contrato de precio
[src:spec/spec-031#§7].

**Sin repositorio**: nada lo verifica dentro de uno solo. Lo cubre un paso de la
guía de pruebas.

## c1 · Precio resuelto en el motor

`rates.ts` devuelve el precio final para una fecha festiva
[src:spec/spec-031#§2].

## c3 · La etiqueta no calcula

`priceLabel.tsx` muestra lo que recibe [src:spec/spec-031#§4].

## Fuera del contrato

Temporada alta, explícitamente [src:spec/spec-031#§9].
