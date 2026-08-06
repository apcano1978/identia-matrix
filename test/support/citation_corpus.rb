# frozen_string_literal: true

# El corpus de citas contra el que se prueba la gramática.
#
# Vive aquí y no dentro de un test porque lo usan dos: el de la gramática
# (`Citations::GrammarTest`) y el del contrato con el brain (`ContractsTest`),
# que comprueba que los dos aceptan y rechazan exactamente lo mismo.
#
# Si el corpus viviera en uno de los dos, correr el otro por separado lo dejaría
# sin definir — y el candado que este corpus sostiene se apagaría en silencio.
module CitationCorpus
  # Las que aparecen literalmente en la maqueta aprobada: el cuerpo de
  # spec-031, el panel REFS, las trazas del DoD, los cuatro pasos de
  # guia-pruebas-031 y el bloque de evidencia de verify-031-r2.
  MOCKUP = [
    "[src:doc/acta-precios#p2]",
    "[src:code/booking-core:rates.ts#L40@4f2a9c1]",
    "[src:code/owner-web:priceLabel.tsx#L22@e91b330]",
    "[src:dod/dod-031#c0]",
    "[src:spec/spec-031#§2]",
    "[src:code/pricing-svc:quote.ts#L31@a04e6c2]",
    "[src:spec/spec-031#§4]",
    "[src:code/booking-core:rates.ts#L40@c31d5a8]",
    "[src:spec/spec-031#§7]",
    "[src:code/owner-web:priceLabel.tsx#L22@2d77b90]",
    "[src:spec/spec-031#§9]",
    "[src:meet/2026-05-02@22:40]",
    "[src:verify/pricing-svc:run-174#L88]"
  ].freeze

  # Formas canónicas que la maqueta enseña como plantilla o que fija el plan,
  # pero que no aparecen escritas enteras en ella.
  CANONICAL = [
    "[src:code/booking-core:cache.ts#L88@4f2a9c1]",
    "[src:code/pricing-svc:src/rules/holiday.ts@b7c0d21]",
    "[src:note/2026-05-08-ap]",
    "[src:dod/dod-031#c3]",
    "[src:pkg/pkg-045#deploy]"
  ].freeze

  # Las dos enmiendas aditivas del 5 de agosto de 2026.
  AMENDED = [
    # `close` como noveno tipo: sin él TANK no puede citar la fuente al afirmar
    # que un evolutivo revierte una decisión de otro.
    "[src:close/close-002#§3]",
    "[src:close/close-009]",
    # Sufijo opcional de reunión, para cuando hay más de una el mismo día.
    "[src:meet/2026-05-02-unificacion-precio@22:40]",
    "[src:meet/2026-05-14-festivos-y-tarifa]"
  ].freeze

  VALID = (MOCKUP + CANONICAL + AMENDED).freeze

  # Cada una con el error que representa. Son las que el parser tiene que
  # rechazar, y por tanto las que el contrato con el brain también.
  INVALID = {
    "[src:code/rates.ts#L40@4f2a9c1]" =>
      "código sin calificador de repositorio: no dice de cuál de los tres habla",
    "[src:verify/run-174#L88]" =>
      "evidencia sin repositorio",
    "[src:doc/acta-precios#z9]" =>
      "ancla desconocida",
    "[src:code/booking-core:rates.ts#L40@4f2a]" =>
      "sha demasiado corto",
    "[src:code/booking-core:rates.ts#L40@4f2a9c1d3]" =>
      "sha demasiado largo",
    "[src:slack/canal-precios#p2]" =>
      "tipo de fuente inventado",
    "[src:meet/2026-05@22:40]" =>
      "fecha incompleta",
    "[src:guide/guia-pruebas-031#p03]" =>
      "una guía no es una fuente que se cite: el paso es un destino, no un origen",
    "[src:close/Close-002]" =>
      "mayúsculas en el slug"
  }.freeze
end
