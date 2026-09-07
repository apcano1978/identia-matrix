---
citations:
  - "[src:doc/tarifario-2026#p1]"
  - "[src:meet/2026-05-02@22:40]"
events:
  - kind: progress
    message: "Un turno de entrevista: dos decisiones cerradas, una abierta"
# ⚠ NINGUNO LLEVA `reference`, y no es un descuido.
#
# `Decisions::Apply` se niega —bien— cuando la referencia nombra un ordinal que
# no existe, y en un evolutivo FRESCO no existe ninguno: un fixture con
# `reference: "1"` haría fallar SIEMPRE el primer turno de la vida real. Lo
# llevaba hasta B9, y no se vio porque en B8 nada ejecutaba un turno.
#
# Lo que un turno produce sobre un acta vacía son decisiones NUEVAS, que es lo
# que este fixture imita. La rama de actualización por ordinal la cubren los
# tests de `Decisions::Apply`, que es donde debe estar: un fixture estático no
# puede saber qué ordinales hay al otro lado.
findings:
  - kind: decision
    statement: "¿Quién decide el precio cuando calendario y reserva discrepan?"
    answer: "Una única autoridad de precio: pricing-svc. El resto consulta."
    status: closed
    evidence: "[src:meet/2026-05-02@22:40]"
  - kind: decision
    statement: "¿El recargo de festivo se aplica sobre la tarifa base o sobre el precio ya recargado?"
    answer: "Sobre la tarifa base, y aparece una sola vez."
    status: closed
    evidence: "[src:doc/tarifario-2026#p1]"
  - kind: decision
    statement: "¿Cuánto dura la ventana en la que conviven las dos versiones del contrato de precio?"
    answer: null
    status: open
usage:
  input_tokens: 9800
  output_tokens: 640
  model_used: chat-default
  latency_ms: 6200
---
# Turno de entrevista · {{initiative}}

Un turno **no publica nada**: lo que deja son las decisiones de arriba, que
`Decisions::Apply` reconcilia contra el acta en curso. El acta se publica una
sola vez, al cerrar, con el propósito `requirements`.

## Lo que se ha cerrado en este turno

La autoridad de precio queda en pricing-svc, que es lo que se acordó en la
reunión de arranque [src:meet/2026-05-02@22:40]. El calendario puede seguir
cacheando disponibilidad, pero no precio.

El recargo de festivo se aplica sobre la tarifa base y una sola vez, tal como lo
describe el tarifario [src:doc/tarifario-2026#p1].

## Lo que sigue abierto

La duración de la ventana de convivencia. No bloquea el avance —una decisión
abierta se arrastra, no detiene— pero deja sin plazo verificable el criterio de
compatibilidad entre repositorios, y eso lo levantará MORFEO.
