# La sincronización con identia-platform (F8).
#
# Reparto de papeles, y conviene tenerlo claro porque son tres piezas:
#
#   `Platform::HttpSource`  habla HTTP y traduce nombres. No toca la base de datos.
#   `Platform::Projection`  hace el upsert, congela slugs y marca ausencias.
#   `Platform::Sync`        decide el ámbito, deja constancia y cierra sesiones.
#
# Esto es lo tercero: lo que ni la fuente ni la proyección saben.
#
# ── Dos operaciones, y la diferencia importa ────────────────────────────────
#
#   `discover`  quién existe: el catálogo de clientes y los usuarios. Global.
#   `call`      lo de UN cliente: sus proyectos, documentos y transcripciones.
#
# Están separadas porque `synced_at` tiene que poder creerse. Si una pasada de
# vivla refrescara de paso la fila de caser, la ficha de caser diría «al día»
# teniendo sus documentos de hace tres días — y un desfase que no se ve es
# exactamente lo que esta fase existe para evitar.
module Platform::Sync
  # Pasado este umbral, la proyección de un cliente se considera desfasada y se
  # avisa en su ficha. Dos horas es un número que solo se sabe si es bueno
  # usándolo; está aquí, en un sitio, para poder cambiarlo cuando se sepa.
  STALE_AFTER = 2.hours

  Result = Data.define(:client, :report, :closed_sessions) do
    def to_s
      etiqueta = client ? client.slug : "catálogo"
      cierres = closed_sessions.positive? ? " · #{closed_sessions} sesiones cerradas" : ""
      "#{etiqueta} · #{report}#{cierres}"
    end
  end

  module_function

  # Quién existe. Descubre clientes nuevos y revalida el acceso de todo el mundo.
  #
  # No trae fuentes: eso es de `call`, cliente a cliente.
  def discover
    source = Platform::Source.current
    report = Platform::Projection.import(source, only: %i[clients users])

    Result.new(client: nil, report: report, closed_sessions: revalidate_users)
  end

  # Lo de un cliente. Nunca una pasada que mezcle dos.
  def call(client)
    source = Platform::Source.current(client: client)
    report = Platform::Projection.import(source, client: client,
                                                 only: %i[projects documents meetings])

    stamp(client)
    record_event(client, report, source)
    Result.new(client: client, report: report, closed_sessions: 0)
  end

  # El latido: primero quién existe, luego lo de cada uno. En ese orden, porque
  # un cliente nuevo tiene que existir antes de que se le pidan sus fuentes.
  def all
    [ discover ] + Platform::Client.active.where(missing_since: nil).map { |client| call(client) }
  end

  # `sources_synced_at` y NO `synced_at`. El segundo lo pone `Projection` en cada
  # fila que toca y significa «esta fila se refrescó»; descubrir el catálogo lo
  # actualiza en todos los clientes sin haber mirado las fuentes de ninguno.
  # La ficha de un cliente tiene que contestar la otra pregunta.
  def stamp(client)
    Platform::Record.writing { client.update!(sources_synced_at: Time.current) }
  end

  # **Deshabilitar a alguien en platform no le echa de matrix.** La sesión es de
  # matrix y sobrevive hasta caducar: es el reverso de la ventaja de tener
  # proyección —que una caída de platform no expulse a quien está trabajando— y
  # hay que cerrarlo aquí.
  #
  # No se comprueba en cada petición a propósito: preguntar a platform en cada
  # carga de página ataría la interfaz de matrix a la disponibilidad de otro
  # servicio, que es justo lo que la proyección existe para evitar. El peor caso
  # de retraso es un latido, quince minutos.
  def revalidate_users
    Session.where(platform_user: Platform::User.where.not(id: Platform::User.with_access))
           .delete_all
  end

  # `08:40:00 SYNC vivla · 14 docs · 9 transcripciones · solo lectura`, que es
  # lo que la maqueta enseña. El evento cuelga del CLIENTE y no de un evolutivo:
  # una sincronización no es de ninguno en particular.
  def record_event(client, report, source)
    Event.create!(
      occurred_at: Time.current,
      actor: "SYNC",
      kind: "platform_synced",
      platform_client: client,
      message: "#{client.slug} · #{report} · solo lectura",
      payload: { source: source.name, created: report.created,
                 updated: report.updated, missing: report.missing })
  end
end
