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

`read.v1.json` describía el contrato **deseado**, no el que platform sirve. Desde
el **24 de agosto de 2026** describe el que sirve: F7 construyó los endpoints que
faltaban y el esquema se enmendó para casar con ellos.

Las tres cosas que faltaban, cerradas:

1. **Ya hay endpoint de reuniones de cliente**: `GET /internal/v1/meetings`, con
   scope `matrix:sources:read`. No confundirlo con `/strategy_meetings`, que son
   las reuniones internas de estrategia y van por `meetings:read`.
2. **`client_documents`** sirve el modelo `Document` del CRM.
   `/internal/v1/documents` sigue sirviendo `natasha_documents` —la memoria
   privada de la agente— y no ha cambiado.
3. **El cuerpo sigue sin estar en tabla**, y por eso hay regla de forma: el
   índice **no** trae `cuerpo` ni `adjuntos`; el detalle sí. Doscientos
   documentos con cuerpo serían doscientas descargas de S3 en una petición.

Y la cuarta, la de forma: `projects` expone **`client_id` aplanado**, para que
matrix no replique la cadena `Lead → Budget → BudgetVersion → Project`.

### La enmienda: el contrato habla el idioma de platform

El esquema original usaba `platform_id`, `name`, `title`, `held_on`, `body`. La
API de platform usa `id`, `nombre`, `titulo`, `fecha`, `cuerpo`, como sus otros
doce endpoints internos.

**Se dobló este lado.** Platform sirve una docena de endpoints en su convención y
Natasha depende de ellos en producción; añadir dos en otra habría dejado su API
bilingüe para siempre. La traducción a los nombres de dominio de matrix la hace
`Platform::Sync` en F8, que es donde va un adaptador.

Se enmendó la **v1** en vez de crear una v2 porque **no hay consumidores
todavía** —el primero es F8—, que es la misma excepción que la regla de
compatibilidad de más arriba contempla. Esa ventana se cierra cuando F8 entre en
marcha.

### Dos decisiones del esquema que conviene no deshacer

- **Los recursos admiten propiedades adicionales.** Si platform añade un campo,
  matrix no revienta. Lo que matrix necesita va en `required`, que es lo que sí
  detecta la deriva que importa: que algo **desaparezca** o cambie de tipo.
- **La regla de cero PII no se hace cumplir aquí.** `projects` sirve `pm` —el
  nombre del jefe de proyecto— y este esquema lo tolera, porque prohibirlo
  obligaría a cambiar la forma de un endpoint del que depende Natasha. Se hace
  cumplir donde de verdad se puede: **el esquema de matrix no tiene columna
  donde guardarlo**. Un campo que llega y no tiene dónde caer, se cae.

  Lo que sí prohíbe el esquema es el nombre del **contacto del cliente** dentro
  de `primary_contact`, que era el caso que la maqueta pedía y F7 §5 descartó.

### Lo que hay más allá de la lectura

`read.v1.json` cubre también dos cosas que no son índices de datos:

- **`POST /internal/v1/authenticate`** (F7 §2.4), con el que matrix verifica una
  contraseña. Platform autentica y devuelve el rol; **quién entra en matrix lo
  decide matrix**.
- **`GET /internal/v1/users`**, que no estaba en la guía de F7 y hace falta:
  matrix proyecta `platform_users`, y F8 §A.3 bis revalida esa proyección para
  cerrar las sesiones de quien haya sido deshabilitado en platform.

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
