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
      city: "Madrid" },
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

  # La maqueta llama «approver» y «observer» al papel en un evolutivo, no al rol
  # de acceso. Matrix todavía no distingue ese papel: los dos son personal
  # interno de platform y los dos entran. Ver F2 §1.3.
  USERS = [
    { platform_id: 1, email_address: "antonio.perez@identiaconsulting.com",
      name: "Antonio Pérez", role: :superadmin, cargo: "CTO" },
    { platform_id: 2, email_address: "matilde.armentano@identiaconsulting.com",
      name: "Matilde Armentano", role: :admin }
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

  # Las fuentes de ORIGEN que las citas de la maqueta resuelven. Sin ellas,
  # `[src:doc/acta-precios#p2]` apuntaría a nada.
  DOCUMENTS = [
    { platform_id: 5001, slug: "acta-precios",
      title: "Acta · unificación del precio de festivos",
      client_platform_id: 101, project_platform_id: 2291,
      body: "El precio mostrado al propietario y el de reserva divergen en " \
            "festivos. Se acuerda una sola fuente." }
  ].freeze

  MEETINGS = [
    { platform_id: 6001, slug: "unificacion-precio",
      title: "Unificación del precio", held_on: Date.new(2026, 5, 2),
      client_platform_id: 101, project_platform_id: 2291,
      duration_seconds: 81_600,
      body: "La tarifa de reserva es la fuente única. El importe se muestra " \
            "tal cual llega del servicio, sin redondeo en cliente." },
    { platform_id: 6002, slug: "festivos-y-tarifa",
      title: "Festivos y tarifa base", held_on: Date.new(2026, 5, 14),
      client_platform_id: 101, project_platform_id: 2291,
      body: "El recargo de festivo aparece una sola vez. Durante el " \
            "despliegue conviven dos versiones del contrato de precio." }
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
  PKG_045 = {
    code: "pkg-045", tasks_count: 19, new_files_count: 5,
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
