---
citations:
  - "[src:meet/2026-05-02@22:40]"
  - "[src:doc/tarifario-2026#p1]"
  - "[src:meet/2026-05-26@11:02]"
  - "[src:doc/contrato-sla-precio#p3]"
events:
  - kind: note
    message: "Acta cerrada · 9 cerradas · 2 abiertas"
findings: []
usage:
  input_tokens: 24600
  output_tokens: 3180
  model_used: chat-default
  latency_ms: 19400
---
# Acta de decisiones · {{initiative}}

> {{title}}
>
> El acta se cierra con **dos decisiones abiertas**. Ninguna bloquea el avance:
> se arrastran, MORFEO las levanta como advertencia y LINK las recupera al
> cerrar. Lo que no puede pasar es que se pierdan.

## cerrada-1 · Autoridad de precio

**¿Quién decide el precio cuando calendario y reserva discrepan?**

Una única autoridad de precio: pricing-svc. El resto consulta y puede cachear
disponibilidad, nunca precio. [src:meet/2026-05-02@22:40]

## cerrada-2 · Base del recargo

**¿El recargo de festivo se aplica sobre la tarifa base o sobre el precio ya
recargado?**

Sobre la tarifa base, y aparece una sola vez. [src:doc/tarifario-2026#p1]

## descartada-3 · Temporada alta

**¿Entra el precio de temporada alta en este cambio?**

Fuera de alcance. Se cierra el festivo y nada más.
[src:meet/2026-05-26@11:02]

Descartada no es cerrada con respuesta «no»: descartar **acota** el trabajo,
cerrar lo **define**. La diferencia importa cuando alguien pregunte, dentro de
tres meses, por qué esto no está.

## abierta-4 · Ventana de convivencia

**¿Cuánto dura la ventana en la que conviven las dos versiones del contrato de
precio?**

Sin respuesta. No bloquea la firma, pero deja el criterio de compatibilidad
entre repositorios sin plazo verificable.

## abierta-5 · Reservas ya confirmadas

**¿Qué pasa con las reservas ya confirmadas a precio antiguo?**

Sin respuesta. El SLA obliga a respetar el precio confirmado
[src:doc/contrato-sla-precio#p3], así que la respuesta más probable es «se
respetan», pero eso lo decide el cliente y no el ARQUITECTO.
