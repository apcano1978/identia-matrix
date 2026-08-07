# Los datos de la maqueta, literales.
#
# Salen del bloque `<script type="text/x-dc">` de
# `identia-matrix-design/identia-matrix-terminal.html`, que es la fuente. Están
# aquí como constantes y no repartidos por el seeder para que se puedan leer sin
# leer código, y para que comparar con la maqueta sea mirar dos tablas.
#
# **Tres restos de la maqueta NO se copian**, y cada uno se marca donde toca:
# la spec va por v4 en todas partes, `dod-031#c3` traza a ORIGEN, y el nodo de
# CLAUDE CODE sigue la regla de glifo —`»` solo mientras ejecuta— en vez del
# `»` que la maqueta deja puesto en nodos ya terminados.
module DesignSeed::Catalog
  CLIENTS = [
    { platform_id: 101, slug: "vivla", name: "VIVLA", sector: "proptech",
      city: "Madrid", primary_contact_role: "cto" },
    { platform_id: 102, slug: "caser", name: "CASER", sector: "seguros",
      city: "Madrid" },
    { platform_id: 103, slug: "navantia", name: "NAVANTIA",
      sector: "industrial", city: "Cartagena" },
    { platform_id: 104, slug: "mango", name: "MANGO", sector: "retail",
      city: "Barcelona" },
    { platform_id: 105, slug: "grifols", name: "GRIFOLS",
      sector: "life sciences", city: "Barcelona" },
    { platform_id: 106, slug: "cirsa", name: "CIRSA", sector: "gaming",
      city: "Terrassa" }
  ].freeze

  # LOS USUARIOS NO SON DE LA MAQUETA: reflejan la base de desarrollo de
  # identia-platform, campo a campo.
  #
  # Es la única parte de esta proyección que no es ficción, y la frontera es
  # deliberada. Los clientes, los evolutivos y las fuentes SÍ son la maqueta:
  # nadie inicia sesión como `vivla`, así que un cliente de demostración no
  # engaña a nadie. Con un usuario, en cambio, TE IDENTIFICAS — y tener dos
  # correos para la misma persona según la pantalla se paga cada día.
  #
  # La maqueta inventaba `antonio.perez@…` y una compañera que platform no tiene.
  # Cuando F8 traiga la sincronización de verdad, esta lista desaparece: la
  # llenará `Platform::Sync` con lo que platform diga en cada momento.
  #
  # (La maqueta llama «approver» y «observer» al papel en un evolutivo, no al rol
  # de acceso. Matrix todavía no distingue ese papel. Ver F2 §1.3.)
  USERS = [
    { platform_id: 1, email_address: "antonio@identiaconsulting.com",
      name: "Antonio Pérez", role: :admin, cargo: "CIO · Founder" }
  ].freeze

  PROJECTS = [
    { platform_id: 2291, platform_project_ref: "proj-2291",
      name: "Unificar precios y calendario", client_platform_id: 101 },
    { platform_id: 2104, platform_project_ref: "proj-2104",
      name: "Motor de disponibilidad", client_platform_id: 101 },
    { platform_id: 2110, platform_project_ref: "proj-2110",
      name: "Portal del copropietario", client_platform_id: 101 },
    { platform_id: 1987, platform_project_ref: "proj-1987",
      name: "Alta de socio autoservicio", client_platform_id: 101 },
    { platform_id: 1840, platform_project_ref: "proj-1840",
      name: "Calendario compartido base", client_platform_id: 101 },
    { platform_id: 2277, platform_project_ref: "proj-2277",
      name: "Triaje asistido", client_platform_id: 102 },
    { platform_id: 2281, platform_project_ref: "proj-2281",
      name: "Migración PLM", client_platform_id: 103 },
    { platform_id: 2263, platform_project_ref: "proj-2263",
      name: "Omnicanal · inventario", client_platform_id: 104 },
    { platform_id: 2255, platform_project_ref: "proj-2255",
      name: "LIMS · trazabilidad de lote", client_platform_id: 105 },
    { platform_id: 2302, platform_project_ref: "proj-2302",
      name: "BI de sala", client_platform_id: 106 }
  ].freeze

  # Las fuentes de ORIGEN. Once documentos y siete reuniones de vivla: nueve en
  # el ámbito de ev-031 y nueve heredadas del cliente, que son las dos cifras
  # que enseña la pantalla de fuentes.
  #
  # Ojo con dos cosas que la maqueta escribe y aquí no se copian:
  #
  #  · La maqueta los nombra con extensión —`acta-precios.pdf`,
  #    `tarifario-2026.xlsx`—. `Platform::Document` no tiene columna de fichero
  #    ni de tipo, y lo que hay que enseñar es el SLUG: es lo que va dentro de
  #    la cita, y por tanto lo único que sirve para escribirla.
  #  · Los documentos heredados van SIN cuerpo a propósito. Es el caso real del
  #    PDF del que nadie extrajo texto: se listan, se pueden citar, pero el
  #    bloque de extracto se omite en vez de enseñar un hueco.
  DOCUMENTS = [
    # En el ámbito de ev-031 · el precio de festivos
    { platform_id: 5001, slug: "acta-precios",
      title: "Acta · unificación del precio de festivos",
      client_platform_id: 101, project_platform_id: 2291,
      body: "El precio mostrado al propietario y el de reserva divergen en " \
            "festivos. Se acuerda una única autoridad de precio, consultada " \
            "por el resto." },
    { platform_id: 5002, slug: "tarifario-2026",
      title: "Tarifario 2026 · temporada y festivos",
      client_platform_id: 101, project_platform_id: 2291,
      body: "El recargo de festivo se aplica sobre la tarifa base, nunca " \
            "sobre el precio ya recargado." },
    { platform_id: 5003, slug: "contrato-sla-precio",
      title: "SLA · disponibilidad del servicio de precio",
      client_platform_id: 101, project_platform_id: 2291,
      body: "El servicio de precio responde en menos de 300 ms el 99 % de " \
            "las peticiones." },
    { platform_id: 5004, slug: "matriz-de-casos-de-precio",
      title: "Matriz de casos · festivo, puente y temporada",
      client_platform_id: 101, project_platform_id: 2291 },
    { platform_id: 5005, slug: "informe-incidencias-precio-q1",
      title: "Incidencias de precio · primer trimestre",
      client_platform_id: 101, project_platform_id: 2291 },

    # Heredados del cliente · documentación general, visible por defecto
    { platform_id: 5006, slug: "marco-contractual-ddb",
      title: "Marco contractual", client_platform_id: 101 },
    { platform_id: 5007, slug: "glosario-negocio",
      title: "Glosario de negocio", client_platform_id: 101,
      body: "Propietario: quien cede la vivienda. Reserva: la estancia " \
            "contratada. Tarifa: el precio por noche antes de recargos." },
    { platform_id: 5008, slug: "arquitectura-corporativa",
      title: "Arquitectura corporativa", client_platform_id: 101 },
    { platform_id: 5009, slug: "politica-de-datos",
      title: "Política de datos y retención", client_platform_id: 101 },
    { platform_id: 5010, slug: "plan-de-continuidad",
      title: "Plan de continuidad", client_platform_id: 101 },
    { platform_id: 5011, slug: "manual-de-marca",
      title: "Manual de marca", client_platform_id: 101 }
  ].freeze

  # `duration_seconds` de la primera: 1:12:40, que es lo que dice la maqueta.
  # Estaba en 81.600 —22h40m— por haber leído la duración del `@22:40` de la
  # cita, que no es una duración sino una marca de tiempo dentro de la
  # transcripción.
  MEETINGS = [
    # En el ámbito de ev-031
    { platform_id: 6001, slug: "unificacion-precio",
      title: "Unificación del precio", held_on: Date.new(2026, 5, 2),
      client_platform_id: 101, project_platform_id: 2291,
      duration_seconds: 4_360,
      body: "La tarifa de reserva es la fuente única. El importe se muestra " \
            "tal cual llega del servicio, sin redondeo en cliente." },
    { platform_id: 6002, slug: "festivos-y-tarifa",
      title: "Festivos y tarifa base", held_on: Date.new(2026, 5, 14),
      client_platform_id: 101, project_platform_id: 2291,
      duration_seconds: 2_282,
      body: "El recargo de festivo aparece una sola vez. Durante el " \
            "despliegue conviven dos versiones del contrato de precio." },
    { platform_id: 6003, slug: "repaso-de-convivencia",
      title: "Repaso de la ventana de convivencia",
      held_on: Date.new(2026, 5, 21), client_platform_id: 101,
      project_platform_id: 2291, duration_seconds: 1_845,
      body: "Mientras convivan las dos versiones, el contrato viejo tiene " \
            "que seguir sirviéndose sin cambios." },
    { platform_id: 6004, slug: "cierre-de-alcance",
      title: "Cierre de alcance", held_on: Date.new(2026, 5, 26),
      client_platform_id: 101, project_platform_id: 2291,
      duration_seconds: 1_510,
      body: "El precio de temporada alta queda fuera de este evolutivo." },

    # Heredadas del cliente
    { platform_id: 6005, slug: "comite-de-direccion",
      title: "Comité de dirección", held_on: Date.new(2026, 3, 4),
      client_platform_id: 101, duration_seconds: 5_400 },
    { platform_id: 6006, slug: "revision-trimestral",
      title: "Revisión trimestral", held_on: Date.new(2026, 4, 9),
      client_platform_id: 101, duration_seconds: 3_720 },
    { platform_id: 6007, slug: "onboarding-marca",
      title: "Onboarding de marca", held_on: Date.new(2026, 2, 14),
      client_platform_id: 101, duration_seconds: 2_940 }
  ].freeze

  # La FRASE que cada cita afirma estar citando, dentro del párrafo que su
  # ancla selecciona. El ancla `#p2` señala un párrafo; esto señala la frase.
  #
  # Lo sabe quien emite la cita, no quien la lee: aquí lo siembra el catálogo y
  # desde F9 lo traerá el agente en su respuesta. Sin declararla habría que
  # adivinarla, y un resaltado adivinado es peor que ninguno.
  QUOTES = {
    "[src:doc/acta-precios#p2]" => "una única autoridad de precio",
    "[src:meet/2026-05-02@22:40]" =>
      "El importe se muestra tal cual llega del servicio",
    "[src:meet/2026-05-02-unificacion-precio@22:40]" =>
      "La tarifa de reserva es la fuente única",
    "[src:dod/dod-031#c3]" => "redondeo en cliente"
  }.freeze

  # Los cierres de los evolutivos ya publicados.
  #
  # Existen porque la MEMORIA entre evolutivos es el valor central del sistema y
  # sin ellos era decorativa: `[src:close/close-002#§3]` se cita en tres sitios
  # del corpus y no resolvía contra nada. Un cierre publicado es lo que permite
  # que un evolutivo posterior afirme «esto ya se decidió, y así».
  #
  # No se usa la fixture de LINK: la escribió TANK para ev-031 y cita su
  # paquete y su DoD, que en febrero no existían. Un cierre que cita el futuro
  # se lee como imposible.
  CLOSURES = [
    { initiative: "ev-002", repository: "booking-core", sha: "3e81f5c",
      what: "El calendario de disponibilidad pasó a resolverse en una sola " \
            "consulta, con la ocupación ya agregada.",
      decision: "Se aceptó deuda a seis meses en el cálculo de solapes: el " \
                "caso de la reserva partida queda sin cubrir.",
      price: "El calendario NO decide precio. Devuelve disponibilidad y " \
             "nada más; quien quiera el importe, que pregunte al servicio " \
             "de precio." },
    { initiative: "ev-009", repository: "owner-web", sha: "71ff230",
      what: "El alta de socio dejó de pasar por soporte: el propietario " \
            "completa sus datos y firma en el mismo paso.",
      decision: "La verificación documental se mantuvo manual. " \
                "Automatizarla exigía un proveedor que no está contratado.",
      price: "El alta no muestra tarifas. Enseñar precio antes de la firma " \
             "obligaba a resolver festivos, y eso es otro evolutivo." }
  ].freeze

  # El ÁMBITO de cada evolutivo: qué fuentes se le acotan explícitamente.
  #
  # Es un FILTRO, no una copia. Su ausencia significa «heredada del cliente»,
  # que es lo visible por defecto: un documento vive una sola vez, en platform,
  # y aparece en tantos evolutivos como haga falta. Por eso `acta-precios` está
  # en ev-031 y en ev-014 — y por eso la pantalla lo marca «también en ev-014».
  #
  # `refs` es el número de referencias en el corpus del cliente, no el de citas
  # dentro de artefactos de matrix: son cosas distintas y la segunda no se
  # deriva de la primera. En F8 lo mantiene el indexador.
  INITIATIVE_SOURCES = [
    { initiative: "ev-031", doc: "acta-precios",                 refs: 7 },
    { initiative: "ev-031", doc: "tarifario-2026",               refs: 4 },
    { initiative: "ev-031", doc: "contrato-sla-precio",          refs: 2 },
    { initiative: "ev-031", doc: "matriz-de-casos-de-precio",    refs: 2 },
    { initiative: "ev-031", doc: "informe-incidencias-precio-q1", refs: 1 },
    { initiative: "ev-031", meet: "unificacion-precio",          refs: 5 },
    { initiative: "ev-031", meet: "festivos-y-tarifa",           refs: 3 },
    { initiative: "ev-031", meet: "repaso-de-convivencia",       refs: 1 },
    { initiative: "ev-031", meet: "cierre-de-alcance",           refs: 1 },

    # El mismo documento, en el ámbito de otro evolutivo. Sin esta fila el
    # concepto entero —ámbito es un filtro, no posesión— no se ve en pantalla.
    { initiative: "ev-014", doc: "acta-precios",                 refs: 3 }
  ].freeze

  REPOSITORIES = [
    { client: "vivla", name: "booking-core", head_sha: "f7b2e04",
      files_count: 3412 },
    { client: "vivla", name: "owner-web", head_sha: "6ba4c17",
      files_count: 1880 },
    { client: "vivla", name: "pricing-svc", head_sha: "a04e6c2",
      files_count: 640 },
    { client: "caser", name: "triaje-core", head_sha: "a02f781" },
    { client: "navantia", name: "plm-core", head_sha: "5b18c73" },
    { client: "mango", name: "omni-core", head_sha: "9f31a7d" },
    { client: "grifols", name: "lims-core", head_sha: "c4d9e02" },
    { client: "cirsa", name: "bi-ingest", head_sha: "7d11ba4",
      files_count: 3900 }
  ].freeze

  ADRS = [
    { repository: "booking-core", code: "ADR-004",
      title: "caché materializada por propiedad", initiative: "ev-002",
      status: :current },
    # En disputa: ev-014 contradice lo que ev-002 decidió. No se borra ni se
    # reescribe — se marca, y alguien decide.
    { repository: "booking-core", code: "ADR-007",
      title: "invalidación incremental por rango", initiative: "ev-014",
      status: :disputed },
    { repository: "owner-web", code: "ADR-011",
      title: "el importe se muestra tal cual llega del servicio",
      initiative: "ev-031", status: :current },
    { repository: "pricing-svc", code: "ADR-012",
      title: "única autoridad de precio del sistema", initiative: "ev-031",
      status: :current }
  ].freeze

  # Los doce nodos de cada evolutivo, tal como los declara PIPES en la maqueta:
  # [estado, subtítulo, marca derecha]. `pend` NO genera fila: en este modelo
  # una etapa pendiente es la AUSENCIA de fila, y así lo lee Pipeline::Glyph.
  #
  # `exec` con marca `✓` se traduce a `done`, no a `active`. Es el tercer resto
  # de la maqueta que no se copia: pinta `»` en nodos ya completos.
  INITIATIVES = [
    { code: "ev-031", client: "vivla", project: 2291,
      title: "Unificar precios y calendario", opened_on: "2026-05-02",
      repositories: %w[booking-core owner-web pricing-svc],
      pinned: { "booking-core" => "4f2a9c1", "owner-web" => "e91b330",
                "pricing-svc" => "b7c0d21" },
      iteration: 4, qa_cycles: 2,
      pipe: [
        %w[done] + [ "", "02 may" ],
        [ "done", "contexto · 3 repos · 24 fuentes", "✓" ],
        [ "done", "spec-031 · v4 conforme", "✓" ],
        [ "done", "dod-031 v2 · 11 criterios", "✓" ],
        [ "done", "revisión spec + DoD", "✓" ],
        [ "done", "pkg-045 · 19 tareas · 3 repos", "✓" ],
        [ "gate", "3 commits sellados", "29 may" ],
        [ "exec", "19/19 tareas · 3 repos", "✓" ],
        [ "done", "✓9 · ⊗2 · conforme", "hoy" ],
        [ "gate2", "guia-pruebas-031 · 2/4 pasos", "6h" ]
      ],
      # Lo que la maqueta narra pero el strip no puede enseñar: MORFEO devolvió
      # una vez —«v1 no traía c0»— y hubo dos ciclos de QA.
      prior: [
        { stage: "morfeo", iteration: 1, status: "failed",
          summary: "v1 no traía c0", metric: "↺" },
        { stage: "seraph_verification", iteration: 3, status: "failed",
          summary: "✕1 · c3", metric: "↺" }
      ] },
    { code: "ev-014", client: "vivla", project: 2104,
      title: "Motor de disponibilidad", opened_on: "2026-04-27",
      repositories: %w[booking-core], pinned: { "booking-core" => "4f2a9c1" },
      iteration: 2, qa_cycles: 1,
      pipe: [
        %w[done] + [ "", "27 abr" ],
        [ "done", "contexto · 18 fuentes", "✓" ],
        [ "act", "spec-014 · v4 en curso", "40m" ],
        [ "done", "dod-014 v2 · 9 criterios", "✓" ],
        [ "done", "revisión spec + DoD", "✓" ],
        [ "done", "pkg-036 · 12 tareas", "✓" ],
        [ "gate", "1 commit sellado", "08 may" ],
        [ "exec", "12/12 tareas", "✓" ],
        [ "fail", "✕2 · ?1", "hoy" ]
      ],
      prior: [ { stage: "neo", iteration: 1, status: "done",
                 summary: "spec-014 · v3", metric: "✓" } ] },
    { code: "ev-027", client: "vivla", project: 2110,
      title: "Portal del copropietario", opened_on: "2026-04-14",
      repositories: %w[owner-web], pinned: { "owner-web" => "e91b330" },
      pipe: [
        %w[done] + [ "", "14 abr" ],
        [ "done", "contexto · 11 fuentes", "✓" ],
        [ "done", "spec-027 · v2", "✓" ],
        [ "done", "dod-027 v1 · 8 criterios", "✓" ],
        [ "done", "sin bloqueantes", "✓" ],
        [ "done", "pkg-039 · 9 tareas", "✓" ],
        [ "done", "1 commit sellado", "03 may" ],
        [ "done", "9/9 tareas", "✓" ],
        [ "done", "✓8 de 8", "12 may" ],
        [ "done", "validado por ap@identia", "18 may" ],
        [ "act", "close-027 v1 · 2 desvíos", "5h" ]
      ] },
    { code: "ev-009", client: "vivla", project: 1987,
      title: "Alta de socio autoservicio", opened_on: "2026-04-02",
      repositories: %w[booking-core owner-web],
      pinned: { "booking-core" => "9c04b11", "owner-web" => "71ff230" },
      pipe: [
        %w[done] + [ "", "02 abr" ],
        [ "done", "contexto · 14 fuentes", "✓" ],
        [ "done", "spec-009 · v3", "✓" ],
        [ "done", "dod-009 v1 · 7 criterios", "✓" ],
        [ "done", "sin bloqueantes", "✓" ],
        [ "done", "pkg-028 · 11 tareas · 2 repos", "✓" ],
        [ "done", "2 commits sellados", "08 abr" ],
        [ "done", "11/11 tareas", "✓" ],
        [ "done", "✓7 de 7", "10 abr" ],
        [ "done", "validado por ap@identia", "11 abr" ],
        [ "done", "close-009 v1", "12 abr" ],
        [ "done", "artifacts://vivla/ev-009", "12 abr" ]
      ] },
    { code: "ev-002", client: "vivla", project: 1840,
      title: "Calendario compartido base", opened_on: "2026-02-18",
      repositories: %w[booking-core], pinned: { "booking-core" => "3e81f5c" },
      pipe: [
        %w[done] + [ "", "18 feb" ],
        [ "done", "contexto · 9 fuentes", "✓" ],
        [ "done", "spec-002 · v2", "✓" ],
        [ "done", "dod-002 v1 · 6 criterios", "✓" ],
        [ "done", "deuda aceptada · revisión 6m", "✓" ],
        [ "done", "pkg-014 · 8 tareas", "✓" ],
        [ "done", "1 commit sellado", "28 feb" ],
        [ "done", "8/8 tareas", "✓" ],
        [ "done", "✓6 de 6", "02 mar" ],
        [ "done", "validado por ap@identia", "03 mar" ],
        [ "done", "close-002 v2", "04 mar" ],
        [ "done", "artifacts://vivla/ev-002", "04 mar" ]
      ] },
    { code: "ev-041", client: "caser", project: 2277,
      title: "Triaje asistido", opened_on: "2026-03-12",
      repositories: %w[triaje-core], pinned: { "triaje-core" => "a02f781" },
      pipe: [
        %w[done] + [ "", "12 mar" ],
        [ "done", "contexto · 22 fuentes", "✓" ],
        [ "done", "spec-011 · v2 aprobada", "✓" ],
        [ "done", "dod-011 v1 · 9 criterios", "✓" ],
        [ "done", "sin bloqueantes", "✓" ],
        [ "done", "pkg-031 · 14 tareas · 2 migraciones", "✓" ],
        [ "gate", "espera tu firma", "3d" ]
      ] },
    { code: "ev-019", client: "navantia", project: 2281,
      title: "Migración PLM", opened_on: "2026-04-03",
      repositories: %w[plm-core], pinned: { "plm-core" => "5b18c73" },
      pipe: [
        %w[done] + [ "", "03 abr" ],
        [ "done", "contexto · 16 fuentes", "✓" ],
        [ "done", "spec-019 · v1 aprobada", "✓" ],
        [ "done", "dod-019 v1 · 8 criterios", "✓" ],
        [ "done", "sin bloqueantes", "✓" ],
        [ "done", "pkg-029 · 9 tareas", "✓" ],
        [ "gate", "espera tu firma", "1d" ]
      ] },
    { code: "ev-022", client: "grifols", project: 2255,
      title: "LIMS · trazabilidad de lote", opened_on: "2026-03-20",
      repositories: %w[lims-core], pinned: { "lims-core" => "c4d9e02" },
      pipe: [
        %w[done] + [ "", "20 mar" ],
        [ "done", "contexto · 19 fuentes", "✓" ],
        [ "done", "spec-022 · v2", "✓" ],
        [ "done", "dod-022 v1 · 12 criterios", "✓" ],
        [ "done", "sin bloqueantes", "✓" ],
        [ "done", "pkg-041 · 16 tareas", "✓" ],
        [ "done", "1 commit sellado", "09 may" ],
        [ "exec", "16/16 tareas", "✓" ],
        [ "done", "✓12 de 12 · conforme", "ayer" ],
        [ "gate2", "guia-pruebas-022 · 4/7 pasos", "18h" ]
      ] },
    { code: "ev-024", client: "mango", project: 2263,
      title: "Omnicanal · inventario", opened_on: "2026-03-28",
      repositories: %w[omni-core], pinned: { "omni-core" => "9f31a7d" },
      # Tres `?` y NINGÚN ciclo consumido: los no concluyentes no cuentan.
      qa_cycles: 0,
      pipe: [
        %w[done] + [ "", "28 mar" ],
        [ "done", "contexto · 21 fuentes", "✓" ],
        [ "done", "spec-024 · v2", "✓" ],
        [ "done", "dod-024 v1 · 10 criterios", "✓" ],
        [ "done", "sin bloqueantes", "✓" ],
        [ "done", "pkg-037 · 13 tareas", "✓" ],
        [ "done", "1 commit sellado", "21 may" ],
        [ "exec", "13/13 tareas", "✓" ],
        [ "esc", "?3 · entorno inestable", "1d" ]
      ],
      escalation: :inconclusive_environment },
    { code: "ev-038", client: "cirsa", project: 2302, title: "BI de sala",
      opened_on: "2026-08-01", repositories: %w[bi-ingest], pinned: {},
      pipe: [
        %w[done] + [ "", "01 ago" ],
        [ "act", "indexando · 1.204/3.900 fich.", "25m" ]
      ] }
  ].freeze

  # Lo que cada evolutivo DECIDIÓ en cada repositorio. Es el texto literal del
  # panel de historia de la maqueta, y el producto entero en una línea: sin él,
  # la ficha de repositorio es una lista de identificadores.
  DECISIONS = {
    [ "ev-014", "booking-core" ] =>
      "Invalidación incremental por rango en lugar de reconstrucción anual. " \
      "Techo de dieciséis copropietarios, fijado por nota humana contra el acta.",
    [ "ev-031", "booking-core" ] =>
      "Este repositorio deja de calcular tarifa: pricing-svc pasa a ser la única " \
      "autoridad de precio. Verificado por repositorio; los dos criterios de " \
      "integración quedaron ⊗.",
    [ "ev-009", "booking-core" ] =>
      "Se descartó validar el DNI en el alta: el proveedor no cubría extranjería. " \
      "Decisión de dirección, registrada en el cierre.",
    [ "ev-002", "booking-core" ] =>
      "Origen de availability_cache. La reconstrucción anual se aceptó como deuda " \
      "consciente con revisión a seis meses — vencida.",
    [ "ev-027", "owner-web" ] =>
      "Rediseño del panel de reservas del socio. LINK está redactando el cierre: " \
      "dos desvíos frente al plan.",
    [ "ev-031", "owner-web" ] =>
      "Se retira el redondeo en cliente: el importe se pinta tal cual lo devuelve " \
      "pricing-svc. Lo exigía una transcripción frente al criterio derivado del DoD.",
    [ "ev-009", "owner-web" ] =>
      "Alta guiada en tres pasos. Sin validación documental por decisión de cliente.",
    [ "ev-031", "pricing-svc" ] =>
      "Se crea quote() como única autoridad de precio, con reglas de festivo " \
      "propias. p95 en 62 ms sobre 200 rps."
  }.freeze

  # La configuración de los seis agentes, tal como la enseña la pantalla de
  # AGENTES. Los tres avisos —morfeo_loop, qa_cycle e independencia de LINK— van
  # LITERALES: son reglas del sistema, no texto de relleno.
  #
  # La maqueta pinta en LINK un «permitir reemplazar una versión publicada». No
  # se copia: un artefacto publicado es inmutable, y ofrecer el interruptor
  # sugeriría que la regla se puede apagar.
  AGENT_CONFIGS = {
    tank: {
      "contexto" => { "profundidad" => "repositorio + fuentes del cliente",
                      "indexa_codigo" => true, "indexa_adr" => true }
    },
    neo: {
      "model" => { "engine" => "claude-sonnet-4-6", "max_iterations" => 4,
                   "spec_length" => "standard", "token_budget" => "180k / run" },
      "sources" => { "code" => "read-only · no exec", "docs" => "consult + cite",
                     "meetings" => "consult + cite", "web" => false },
      "citation_rules" => { "require_citation_for_non_derivable" => true,
                            "pin_commit_on_code_refs" => true,
                            "allow_unsourced_inference" => false,
                            "min_citations_per_spec" => 3 },
      "morfeo_loop" => { "max_returns" => 2 }
    },
    morfeo: {
      # `derived_ratio_threshold` vive aquí, y no suelto, porque es una política
      # de revisión: así hereda el override por cliente como el resto de la
      # configuración. Ver Citations::DerivedRatio.
      "revision" => { "bloquea_sin_criterio_multi_repo" => true,
                      "clasifica_bloqueante" => "spec o DoD",
                      "derived_ratio_threshold" => 0.25 }
    },
    trinity: {
      "paquete" => { "exige_orden_de_despliegue" => true,
                     "exige_write_scope" => true }
    },
    seraph: {
      "dod_pass" => { "engine" => "claude-sonnet-4-6", "min_criteria" => 6,
                      "cada_criterio_exige_una_cita" => true,
                      "criterio_medible_o_rechaza_la_spec" => true },
      "qa_cycle" => { "max_qa_cycles" => 2,
                      "inconclusive_y_unsupported_no_consumen" => true },
      "verificacion" => { "fuente" => "CI del repositorio",
                          "sin_red_a_produccion" => true,
                          "sin_credenciales_reales" => true,
                          "runner_entre_servicios" => false },
      "dictamen" => { "permitir_que_seraph_corrija" => false,
                      "salida_de_pruebas_como_evidencia" => true,
                      "emitir_guia_al_dar_conforme" => true }
    },
    link: {
      "contenido_del_cierre" => { "que_se_pidio_y_que_se_construyo" => true,
                                  "desvios_con_su_causa" => true,
                                  "decisiones_y_quien_las_tomo" => true,
                                  "ciclos_de_qa_y_escaladas" => true },
      "publicacion" => { "destino" => "artifacts://<cliente>/<evolutivo>/close-nnn",
                         "plantilla" => "identia/cierre-tecnico v3",
                         "formato" => "markdown · clave inmutable" }
    }
  }.freeze

  # El override que la maqueta enseña en la ficha de vivla.
  AGENT_OVERRIDES = [
    { agent: :neo, client: "vivla", settings: { "model" => { "spec_length" => "verbose" } } }
  ].freeze

  # Los paquetes de los otros dos evolutivos que esperan firma. La maqueta los
  # describe en el dashboard y en su pantalla de GATE 1, así que sin ellos la
  # fila diría «espera tu firma» en lugar de qué es lo que hay que firmar.
  PACKAGES = [
    { initiative: "ev-041", code: "pkg-031", repository: "triaje-core",
      tasks_count: 14, new_files_count: 3, modified_files_count: 7,
      migrations_count: 2, write_scope: "src/triage · src/api · migrations" },
    { initiative: "ev-019", code: "pkg-029", repository: "plm-core",
      tasks_count: 9, new_files_count: 3, modified_files_count: 6,
      migrations_count: 0, write_scope: "src/plm · src/sync · config" }
  ].freeze

  # Los once criterios de dod-031 v2. Los cinco primeros y c5/c6 salen de la
  # tabla de la maqueta; los cuatro restantes son «… 4 criterios más · todos ✓».
  #
  # c3 traza a ORIGEN —el código del cliente—, que es lo que dice la tabla del
  # DoD. El panel de conflicto de la maqueta lo llama derivado: eso es el
  # segundo resto que no se copia.
  DOD_031 = [
    { key: "c0", repository: nil, mandatory_kind: :multi_repo_compatibility,
      critical: true, verdict: :met, trace: "[src:pkg/pkg-045#deploy]",
      statement: "El contrato v1 de precio sigue sirviendo mientras la " \
                 "ventana de despliegue esté abierta." },
    { key: "c1", repository: "pricing-svc", verdict: :met,
      trace: "[src:doc/acta-precios#p2]",
      statement: "pricing-svc es la única autoridad de precio." },
    { key: "c2", repository: "booking-core", verdict: :met,
      trace: "[src:code/booking-core:rates.ts#L40@4f2a9c1]",
      test_ref: "booking-core · rates.spec.ts:18",
      evidence: "0 llamadas a computeRate en la suite",
      evidence_citation: "[src:code/booking-core:rates.ts#L40@c31d5a8]",
      statement: "booking-core deja de calcular tarifa localmente." },
    { key: "c3", repository: "owner-web", verdict: :met,
      trace: "[src:code/owner-web:priceLabel.tsx#L22@e91b330]",
      test_ref: "owner-web · priceLabel.spec.tsx:44",
      evidence: "round() retirado del cliente · 61 tests en verde",
      evidence_citation: "[src:code/owner-web:priceLabel.tsx#L22@2d77b90]",
      statement: "owner-web muestra el precio devuelto, sin recálculo." },
    { key: "c4", repository: "pricing-svc", verdict: :met,
      trace: "[src:code/pricing-svc:src/rules/holiday.ts@b7c0d21]",
      test_ref: "pricing-svc · perf.log L88",
      evidence: "medido 62 ms · el contenedor levantó al segundo intento",
      evidence_citation: "[src:verify/pricing-svc:run-174#L88]",
      statement: "quote() responde en < 80 ms para el p95." },
    # Los dos ⊗: nada los verifica dentro de un solo repositorio. Sin
    # repositorio, sin test, y su única evidencia es un paso de la guía.
    { key: "c5", repository: nil, critical: true, verdict: :unsupported,
      trace: "[src:spec/spec-031#§7]", guide_step: 3,
      statement: "Calendario y precio coinciden extremo a extremo en una " \
                 "reserva real." },
    { key: "c6", repository: nil, critical: true, verdict: :unsupported,
      trace: "[src:meet/2026-05-02@22:40]", guide_step: 4,
      statement: "El festivo local no altera la tarifa base entre servicios." },
    { key: "c7", repository: "booking-core", verdict: :met,
      trace: "[src:spec/spec-031#§2]",
      statement: "El calendario pide la tarifa al servicio de precio." },
    { key: "c8", repository: "booking-core", verdict: :met,
      trace: "[src:spec/spec-031#§4]",
      statement: "Ninguna ruta de reserva devuelve un precio propio." },
    { key: "c9", repository: "owner-web", verdict: :met,
      trace: "[src:spec/spec-031#§9]",
      statement: "El recargo de festivo aparece una sola vez en la ficha." },
    { key: "c10", repository: "booking-core", verdict: :met,
      trace: "[src:code/booking-core:rates.ts#L40@4f2a9c1]",
      statement: "El contrato v1 se retira solo al cerrar la ventana." }
  ].freeze

  # Las tres ejecuciones de CI de verify-031-r2, con sus tiempos.
  CI_031 = [
    { repository: "booking-core", commit_sha: "c31d5a8", status: :green,
      tests_total: 96, duration_seconds: 158 },
    { repository: "owner-web", commit_sha: "2d77b90", status: :green,
      tests_total: 61, duration_seconds: 87 },
    { repository: "pricing-svc", commit_sha: "a04e6c2", status: :green,
      tests_total: 44, duration_seconds: 58 }
  ].freeze

  # Cuatro pasos, de los que DOS son de única evidencia: nadie más los ha
  # comprobado, y sin recorrerlos GATE 2 no se puede validar.
  GUIDE_031 = [
    { position: 1, criterion: "c1", evidence_origin: :auto_verified,
      title: "Precio servido por pricing-svc", walked: true,
      body: "El calendario pide la tarifa al servicio de precio en lugar de " \
            "calcularla. Comprueba que una reserva muestra el importe " \
            "devuelto, sin redondeo propio.\n\n" \
            "[src:spec/spec-031#§2] · [src:code/pricing-svc:quote.ts#L31@a04e6c2]" },
    { position: 2, criterion: "c2", evidence_origin: :auto_verified,
      title: "Retirada del cálculo local", walked: true,
      body: "booking-core ya no computa tarifa. Verifica que ninguna ruta de " \
            "reserva devuelve un precio distinto al del servicio.\n\n" \
            "[src:spec/spec-031#§4] · [src:code/booking-core:rates.ts#L40@c31d5a8]" },
    { position: 3, criterion: "c5", evidence_origin: :sole_evidence,
      title: "Coherencia extremo a extremo", walked: false,
      body: "Reserva real de principio a fin: calendario y precio deben " \
            "coincidir en importe y en tramo. Requiere los tres servicios " \
            "hablándose.\n\n" \
            "[src:spec/spec-031#§7] · [src:code/owner-web:priceLabel.tsx#L22@2d77b90]" },
    { position: 4, criterion: "c6", evidence_origin: :sole_evidence,
      title: "Festivo local sobre la tarifa base", walked: false,
      body: "Con un festivo cargado en pricing-svc, comprueba que la tarifa " \
            "base del calendario no se altera y que el recargo aparece una " \
            "sola vez.\n\n" \
            "[src:spec/spec-031#§9] · [src:meet/2026-05-02@22:40]" }
  ].freeze

  # pkg-045: tres pasos, ventana de ~40 min. El orden es el dato.
  # `number: 45` y no el 31 del evolutivo: el paquete tiene secuencia propia,
  # como documenta Artifacts::Key. De ahí que ev-031 produzca PKG-045.
  PKG_045 = {
    code: "pkg-045", number: 45, tasks_count: 19, new_files_count: 5,
    modified_files_count: 11, migrations_count: 1,
    signed_at: Time.zone.parse("2026-05-29 17:04"),
    statement: "Firmé la entrega de PKG-045 a Claude Code sobre tres " \
               "repositorios y asumí la ventana de despliegue.",
    steps: [
      { repository: "pricing-svc", deploy_order: 1, base_sha: "b7c0d21",
        executed_sha: "a04e6c2", write_scope: "src/quote · src/rules",
        note: "Primero el proveedor de precio. Nadie lo consume todavía." },
      { repository: "booking-core", deploy_order: 2, base_sha: "4f2a9c1",
        executed_sha: "c31d5a8", write_scope: "src/pricing · src/rates",
        note: "Empieza a consultar. Debe seguir sirviendo el contrato v1 a " \
              "owner-web viejo." },
      { repository: "owner-web", deploy_order: 3, base_sha: "e91b330",
        executed_sha: "2d77b90", write_scope: "src/priceLabel · src/api",
        note: "Último. Cierra la ventana y se retira el contrato v1." }
    ]
  }.freeze

  # Traducción de los estados de la maqueta a los del modelo. `exec` con marca
  # `✓` es `done`: la regla de glifo manda sobre lo que la maqueta pinta.
  STATUSES = { "done" => :done, "act" => :active, "gate" => :active,
               "gate2" => :active, "exec" => :done, "fail" => :failed,
               "esc" => :escalated }.freeze
end
