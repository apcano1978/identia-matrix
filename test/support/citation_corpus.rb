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

  # Las cuatro enmiendas aditivas de la gramática. La tercera fue la última antes
  # de que la ventana se cerrara, el 4 de septiembre, cuando TANK produjo el
  # primer artefacto real. La cuarta se hace con la ventana ya cerrada, y el
  # porqué está en la cabecera de Citations::Grammar y demostrado en
  # test/models/citations/amendments_test.rb.
  AMENDED = [
    # `close` como noveno tipo: sin él TANK no puede citar la fuente al afirmar
    # que un evolutivo revierte una decisión de otro.
    "[src:close/close-002#§3]",
    "[src:close/close-009]",
    # Sufijo opcional de reunión, para cuando hay más de una el mismo día.
    "[src:meet/2026-05-02-unificacion-precio@22:40]",
    "[src:meet/2026-05-14-festivos-y-tarifa]",
    # Ordinal de nota (P8, 26 de agosto de 2026), para cuando hay más de una del
    # mismo autor el mismo día. Va ANIDADO tras el autor; el porqué está abajo,
    # en la entrada de INVALID que le corresponde.
    "[src:note/2026-08-17-ap-2]",
    "[src:note/2026-08-17-ap-12#p3]",
    # `acta` como décimo tipo y el ancla de decisión, en F11. Un tipo que no
    # existía no puede cambiar cómo se interpreta nada ya escrito: no hay texto
    # anterior que empiece por `[src:acta/`.
    "[src:acta/arquitecto-031#abierta-1]",
    "[src:acta/arquitecto-031#cerrada-2]",
    "[src:acta/arquitecto-031#descartada-3]",
    "[src:acta/arquitecto-031]"
  ].freeze

  VALID = (MOCKUP + CANONICAL + AMENDED).freeze

  # ── EL FÓSIL ────────────────────────────────────────────────────────────────
  #
  # Cómo interpreta el parser cada cita, campo a campo. NO es una lista de
  # «estas son válidas»: es el significado exacto de cada una, congelado.
  #
  # ⚠ ESTO SE EXTIENDE, NUNCA SE REGENERA. Un fósil que se regenera cuando el
  # test se pone rojo no protege de nada: se limita a grabar lo que acabas de
  # romper. Si una entrada de aquí deja de cuadrar, la respuesta correcta es
  # deshacer la enmienda, no actualizar el fósil.
  #
  # Es lo que convierte «la enmienda es aditiva» en algo comprobado y no
  # prometido. Sobre esto se apoya amendments_test, y cualquier enmienda futura
  # de la gramática tiene que pasarlo.
  #
  # Se generó el 6 de septiembre de 2026 a partir de VALID y de las citas
  # literales de `lib/runtime/fixtures/**/*.md`, que es lo que un agente
  # produce. Las 49 citas realmente emitidas viven en la base de datos y no
  # caben aquí; se comprueban aparte, con el runner que documenta F11.
  INTERPRETATIONS = {
    "[src:acta/arquitecto-031#abierta-1]" =>
      { kind: "acta", locator: "arquitecto-031", anchor: "abierta-1" },
    "[src:acta/arquitecto-031#cerrada-2]" =>
      { kind: "acta", locator: "arquitecto-031", anchor: "cerrada-2" },
    "[src:acta/arquitecto-031#descartada-3]" =>
      { kind: "acta", locator: "arquitecto-031", anchor: "descartada-3" },
    "[src:acta/arquitecto-031]" =>
      { kind: "acta", locator: "arquitecto-031" },
    "[src:close/close-002#§3]" =>
      { kind: "close", locator: "close-002", anchor: "§3" },
    "[src:close/close-009]" =>
      { kind: "close", locator: "close-009" },
    "[src:code/booking-core:cache.ts#L120@4f2a9c1]" =>
      { kind: "code", repository: "booking-core", locator: "cache.ts", anchor: "L120", commit_sha: "4f2a9c1" },
    "[src:code/booking-core:cache.ts#L88@4f2a9c1]" =>
      { kind: "code", repository: "booking-core", locator: "cache.ts", anchor: "L88", commit_sha: "4f2a9c1" },
    "[src:code/booking-core:calendar.ts#L88@4f2a9c1]" =>
      { kind: "code", repository: "booking-core", locator: "calendar.ts", anchor: "L88", commit_sha: "4f2a9c1" },
    "[src:code/booking-core:pricing.ts#L12@4f2a9c1]" =>
      { kind: "code", repository: "booking-core", locator: "pricing.ts", anchor: "L12", commit_sha: "4f2a9c1" },
    "[src:code/booking-core:rates.ts#L40@4f2a9c1]" =>
      { kind: "code", repository: "booking-core", locator: "rates.ts", anchor: "L40", commit_sha: "4f2a9c1" },
    "[src:code/booking-core:rates.ts#L40@c31d5a8]" =>
      { kind: "code", repository: "booking-core", locator: "rates.ts", anchor: "L40", commit_sha: "c31d5a8" },
    "[src:code/owner-web:api.ts#L64@e91b330]" =>
      { kind: "code", repository: "owner-web", locator: "api.ts", anchor: "L64", commit_sha: "e91b330" },
    "[src:code/owner-web:priceLabel.tsx#L22@2d77b90]" =>
      { kind: "code", repository: "owner-web", locator: "priceLabel.tsx", anchor: "L22", commit_sha: "2d77b90" },
    "[src:code/owner-web:priceLabel.tsx#L22@e91b330]" =>
      { kind: "code", repository: "owner-web", locator: "priceLabel.tsx", anchor: "L22", commit_sha: "e91b330" },
    "[src:code/pricing-svc:quote.ts#L31@a04e6c2]" =>
      { kind: "code", repository: "pricing-svc", locator: "quote.ts", anchor: "L31", commit_sha: "a04e6c2" },
    "[src:code/pricing-svc:quote.ts#L31@b7c0d21]" =>
      { kind: "code", repository: "pricing-svc", locator: "quote.ts", anchor: "L31", commit_sha: "b7c0d21" },
    "[src:code/pricing-svc:src/rules/holiday.ts@b7c0d21]" =>
      { kind: "code", repository: "pricing-svc", locator: "src/rules/holiday.ts", commit_sha: "b7c0d21" },
    "[src:doc/acta-precios#p2]" =>
      { kind: "doc", locator: "acta-precios", anchor: "p2" },
    "[src:dod/dod-031#c0]" =>
      { kind: "dod", locator: "dod-031", anchor: "c0" },
    "[src:dod/dod-031#c3]" =>
      { kind: "dod", locator: "dod-031", anchor: "c3" },
    "[src:meet/2026-05-02-unificacion-precio@22:40]" =>
      { kind: "meet", locator: "2026-05-02", clock: "22:40", meeting_slug: "unificacion-precio" },
    "[src:meet/2026-05-02@22:40]" =>
      { kind: "meet", locator: "2026-05-02", clock: "22:40" },
    "[src:meet/2026-05-14-festivos-y-tarifa]" =>
      { kind: "meet", locator: "2026-05-14", meeting_slug: "festivos-y-tarifa" },
    "[src:note/2026-05-08-ap]" =>
      { kind: "note", locator: "2026-05-08", author: "ap" },
    "[src:note/2026-08-17-ap-12#p3]" =>
      { kind: "note", locator: "2026-08-17", anchor: "p3", author: "ap", note_slug: "12" },
    "[src:note/2026-08-17-ap-2]" =>
      { kind: "note", locator: "2026-08-17", author: "ap", note_slug: "2" },
    "[src:pkg/pkg-045#deploy]" =>
      { kind: "pkg", locator: "pkg-045", anchor: "deploy" },
    "[src:spec/spec-031#§2]" =>
      { kind: "spec", locator: "spec-031", anchor: "§2" },
    "[src:spec/spec-031#§4]" =>
      { kind: "spec", locator: "spec-031", anchor: "§4" },
    "[src:spec/spec-031#§7]" =>
      { kind: "spec", locator: "spec-031", anchor: "§7" },
    "[src:spec/spec-031#§9]" =>
      { kind: "spec", locator: "spec-031", anchor: "§9" },
    "[src:verify/owner-web:run-163#L44]" =>
      { kind: "verify", repository: "owner-web", locator: "run-163", anchor: "L44" },
    "[src:verify/pricing-svc:run-174#L88]" =>
      { kind: "verify", repository: "pricing-svc", locator: "run-174", anchor: "L88" }
  }.freeze

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
      "mayúsculas en el slug",

    # ⚠ ESTA ENTRADA ES LA RAZÓN DE QUE EL ORDINAL DE P8 VAYA ANIDADO DENTRO DEL
    # AUTOR, y sin ella nadie volverá a saberlo.
    #
    # Se consideraron las dos formas. Con el ordinal SUELTO —fecha, luego autor
    # opcional, luego sufijo opcional— esta cita pasaría a ser válida y
    # parsearía como fecha `2026-08-17` SIN autor y sufijo `antonio`. Y
    # `Citations::Resolve#note`, sin autor, cae a un LIKE sobre el locator y
    # devuelve la primera nota de ese día: resolvería a la NOTA EQUIVOCADA, en
    # silencio, dentro de un artefacto inmutable que nadie puede reescribir.
    #
    # Anidado tras el autor, `antonio` no puede ser un ordinal porque no hay
    # autor delante que lo sostenga —el autor son dos a cuatro letras—, así que
    # la cita sigue siendo inválida. Que es lo correcto.
    "[src:note/2026-08-17-antonio]" =>
      "un nombre entero no son iniciales de autor, y el ordinal solo existe " \
      "detrás de un autor: suelto, esto parsearía sin autor y resolvería a otra nota",
    "[src:note/2026-08-17-2]" =>
      "ordinal sin autor: el ordinal va anidado tras las iniciales, no suelto"
  }.freeze
end
