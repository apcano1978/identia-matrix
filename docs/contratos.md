# Contratos de identia-matrix

Matrix habla con dos servicios. Los contratos de esas dos juntas viven **aquí y
solo aquí**, versionados en `contracts/`. Los consumidores fijan la versión; no
se duplican entre repositorios.

| Fichero | Dirección | Qué describe |
|---|---|---|
| `contracts/matrix-brain/agent_run.v1.json` | matrix → brain | El cuerpo de `POST /v1/agents/{key}/run` |
| `contracts/matrix-brain/agent_result.v1.json` | brain → matrix | Lo que devuelve una ejecución de agente |
| `contracts/matrix-platform/read.v1.json` | platform → matrix | La lectura de clientes, proyectos y fuentes |

Se validan con `Contracts` (`app/models/contracts.rb`):

```ruby
Contracts.validate!(:matrix_brain_agent_run, payload)   # levanta con los punteros que fallan
Contracts.valid?(:matrix_brain_agent_run, payload)      # true / false
Contracts.errors(:matrix_brain_agent_run, payload)      # ["/context/stage: value not in enum", …]
```

## Por qué existen

Ninguno de los dos vecinos declara versión en sus payloads:

- El **brain** recibe `config` y `context` como `dict` **opacos**. La validación
  real ocurre dentro de `parse_config`, ya en Python. Peor: `context` solo
  reconoce las claves `dedupe_seen_urls` y `source`, y **descarta el resto en
  silencio**. Sin este contrato, matrix podría enviar el evolutivo entero y no
  enterarse de que el brain lo tiró.
- **platform** sirve JSON sin esquema declarado, y hoy ni siquiera sirve dos de
  los cuatro recursos que matrix necesita.

Así que este lado es el único sitio donde la compatibilidad se puede comprobar
de verdad. Por eso la validación ocurre **antes de enviar**, no después de
recibir un error.

## La regla de compatibilidad: evolución aditiva

Un contrato **nunca** cambia de forma que rompa a un consumidor antiguo:

1. **Campo nuevo → siempre con `default`.** Un cliente que no lo envía sigue
   funcionando. Es lo que el brain ya hace con `currency`, `strategy_context` y
   `cache_*_tokens`.
2. **Renombrado → nunca directo.** Se acepta el nombre viejo y se traduce, como
   hace el brain con `_accept_legacy_categories` (`categories` → `tags`).
3. **Un campo no se borra ni se estrecha.** Quitar un valor de un `enum`, subir
   un `minimum` o añadir un `required` son cambios rompedores.
4. **Si hay que romper, sube la versión mayor**: se añade
   `agent_run.v2.json` junto al v1, ambos se sirven a la vez, y el v1 se retira
   cuando ya no queda quien lo use. El nombre del fichero y el `$id` llevan la
   versión precisamente para que puedan convivir.

Hay un test que lo vigila (`test/models/contracts_test.rb`): comprueba que los
tres esquemas declaran `$schema`, `$id` y `title`, y que la versión aparece en el
nombre del fichero y en el `$id`.

## Lo que los contratos codifican, y no es negociable

- **La frontera de cliente.** `agent_run` exige `context.client`. Un agente sin
  cliente no puede ejecutarse: es restricción del modelo, no filtro de la vista.
- **Los cuatro veredictos.** `agent_result` acepta exactamente `met`, `unmet`,
  `inconclusive` y `unsupported` — ✓ ✕ ? ⊗. Solo `unmet` consume ciclo de QA.
  Confundir `inconclusive` o `unsupported` con `unmet` haría que NEO escriba
  specs para arreglar bugs que no existen, que es el error más caro que el
  sistema puede cometer.
- **Las doce etapas**, como `enum` cerrado.
- **El máximo de ciclos de QA**, como `maximum: 2`.
- **La gramática de citas.** Las citas que devuelve un agente se validan con el
  mismo patrón que usa `Citations::Grammar`, y hay un test que comprueba que el
  esquema y el parser no divergen: si el contrato acepta una forma que el parser
  rechaza, un agente podría colar una referencia inventada.
- **`additionalProperties: false` en `context`.** Deliberado: es lo que hace que
  el descarte silencioso del brain se detecte aquí en vez de en producción.

## Un solo escritor

`agent_result` devuelve `body` en markdown **sin front-matter**. El front-matter
lo compone matrix al persistir, porque solo matrix conoce la clave definitiva y
el checksum. El brain devuelve contenido; matrix lo guarda y lo registra. El
brain no escribe en el bucket ni guarda estado de pipeline.

## Estado de la junta con platform

`read.v1.json` describe el contrato **deseado**, no el que platform sirve hoy.
A agosto de 2026 faltan tres cosas, y cerrarlas es la fase **F7**, dentro del
repositorio de platform:

1. No hay endpoint de `meetings`. Las transcripciones no se pueden leer.
2. El endpoint `/internal/v1/documents` que sí existe sirve `natasha_documents`
   —la memoria privada del agente—, que **no** es el modelo `Document` del CRM.
   Por eso el contrato lo llama `client_documents`: para que no colisionen.
3. El cuerpo de documentos y transcripciones **no está en tabla**. Vive en
   `content_versions` (markdown en S3) y en adjuntos de Active Storage. Por eso
   `body` es nullable y hay un bloque `attachments` con `extracted_text`.

Y una cuarta, de forma más que de contenido: en platform, `Project` no apunta al
`Lead` — la cadena es `Lead → Budget → BudgetVersion → Project`. El contrato
exige `client_platform_id` **aplanado** para que matrix no replique esa
navegación.

## Referencias entre servicios

Platform no tiene UUIDs ni slugs en `leads`, `clients`, `projects`, `documents`
ni `meetings`: todo es `bigserial`. Matrix guarda el **`platform_id`** que
devuelve la API, más `platform_project_ref` (`PRJ-2026-9001`) donde existe.

Una excepción importante: **el segmento de cliente de una clave de artefacto no
usa nada de platform**. Usa un slug propio de matrix, congelado en la primera
sincronización y nunca re-sincronizado. Las claves de artefacto son inmutables y
los nombres de cliente en platform se renombran; si la clave dependiera de
platform, un renombrado allí rompería todo lo ya publicado. Ver
`app/models/artifacts/key.rb`.
