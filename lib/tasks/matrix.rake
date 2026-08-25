namespace :matrix do
  desc "Regenera en los contratos lo que se deriva del código (hoy: el patrón de citas)"
  task sync_contracts: :environment do
    path = Rails.root.join("contracts/matrix-brain/agent_result.v1.json")
    definition = JSON.parse(path.read)
    current = definition.dig("properties", "citations", "items", "pattern")

    if current == Citations::Grammar::SCHEMA_PATTERN
      puts "El contrato ya está al día."
      next
    end

    definition["properties"]["citations"]["items"]["pattern"] = Citations::Grammar::SCHEMA_PATTERN
    path.write("#{JSON.pretty_generate(definition)}\n")

    puts "Actualizado el patrón de citas en #{path.relative_path_from(Rails.root)}."
    puts "Revisa el diff: acabas de cambiar lo que el brain puede devolver."
  end

  desc "Reconstruye initiatives.current_stage desde las stage_entries"
  task rebuild_stage_cache: :environment do
    changes = StageCache.rebuild

    if changes.empty?
      puts "El caché de etapa está al día en los #{Initiative.count} evolutivos."
      next
    end

    changes.each do |change|
      puts "#{change.initiative.code}: #{change.from} → #{change.to}"
    end
    puts "#{changes.size} corregidos. Si esto no sale vacío, algo escribió el " \
         "caché sin escribir la fila."
  end

  desc "Siembra los datos de la maqueta (idempotente, nunca en producción)"
  task seed_design: :environment do
    report = DesignSeed.call

    puts report
    puts "Runtime de agentes: #{ENV.fetch('MATRIX_AGENT_RUNTIME', 'fake')} · " \
         "fuente de platform: #{Platform::Source.current.name}"
  end

  desc "Sincroniza la proyección de platform. Un cliente por slug, o todos."
  task :sync, [ :slug ] => :environment do |_task, args|
    unless Platform::Source.real?
      abort "MATRIX_PLATFORM_SOURCE es `fake`: esto sincronizaría el seed contra sí mismo. " \
            "Ponlo a `platform` para hablar con identia-platform de verdad."
    end

    refuse_over_seed! unless ENV["FORCE"] == "1"

    resultados =
      if args[:slug]
        [ Platform::Sync.call(Platform::Client.find_by!(slug: args[:slug])) ]
      else
        Platform::Sync.all
      end

    resultados.each { |resultado| puts resultado }
    puts "Nada que sincronizar: la proyección está vacía." if resultados.empty?
  end

  # 🛡 La maqueta no se pisa sin querer.
  #
  # Los seis clientes y los diez evolutivos de la demostración vienen del seed, y
  # una sincronización real los deja marcados como ausentes —correctamente: no
  # existen en platform—. Eso es irreversible dentro de la misma base, y el día
  # que haga falta enseñar el producto no es el día de descubrirlo.
  #
  # La columna `sync_source` distingue de dónde vino cada fila, así que la
  # comprobación es exacta y no una heurística.
  def refuse_over_seed!
    sembrados = Platform::Client.where(sync_source: "fake").count
    return if sembrados.zero?

    abort <<~AVISO
      La proyección tiene #{sembrados} clientes sembrados de la maqueta.

      Sincronizar contra platform los dejará marcados como ausentes, y con ellos
      los evolutivos, documentos y reuniones de la demostración. No es un fallo
      —no existen en platform— pero tampoco se deshace.

      Para volver a la maqueta después:  make reset && bin/rails matrix:seed_design
      Para sincronizar de todos modos:   FORCE=1 bin/rails "matrix:sync[#{Platform::Client.first&.slug}]"
    AVISO
  end

  desc "Ancla e indexa los repositorios de un evolutivo. Ej: matrix:index[ev-031]"
  task :index, [ :code ] => :environment do |_task, args|
    initiative = Initiative.find_by!(code: args.fetch(:code))

    puts "#{initiative.code} · #{initiative.platform_client.slug} · " \
         "fuente #{Repositories::Source.real? ? 'remota' : 'falsa'}"
    Repositories::Index.call(initiative: initiative, actor: "manual").each do |result|
      puts "  #{result}"
    end
  end

  desc "Guarda la credencial de LECTURA de un cliente. Ej: TOKEN=ghp_… matrix:credential[evalora,github.com]"
  task :credential, [ :client, :host ] => :environment do |_task, args|
    # El valor llega por variable de entorno y no por argumento: lo que se
    # escribe en la línea de `rake` queda en el historial del shell, y esto es
    # un secreto. Por la misma razón no hay formulario — un token en un POST
    # acaba en logs de acceso y en el historial del navegador.
    token = ENV["TOKEN"].to_s.strip
    abort "Falta TOKEN=… en el entorno." if token.empty?

    client = Platform::Client.find_by!(slug: args.fetch(:client))
    host = args[:host].presence || "github.com"

    anterior = RepositoryCredential.current_for(client, host)
    credential = RepositoryCredential.create!(
      platform_client: client, host: host, token: token,
      note: "emitida a mano#{anterior ? ' · rota la anterior' : ''}")

    puts "#{client.slug} · #{credential}"
    puts "Manda la más reciente; la anterior queda como rastro." if anterior
    puts "SOLO LECTURA: matrix no escribe en un repositorio ajeno en ninguna fase."
  end

  desc "Lista las credenciales de lectura vivas, sin revelar su valor."
  task credentials: :environment do
    vigentes = Platform::Client.active.filter_map do |client|
      RepositoryCredential.where(platform_client: client).latest_first.first
    end

    if vigentes.empty?
      puts "Ninguna credencial emitida. Los repositorios públicos se leen igual."
      next
    end

    vigentes.each { |c| puts "#{c.platform_client.slug.ljust(20)} #{c}" }
  end

  desc "Recorre un evolutivo por las doce etapas con el runtime falso"
  task :walk_pipeline, [ :code, :variant ] => :environment do |_task, args|
    code = args[:code].presence || "ev-999"
    # Se admite `--fail-once` además de `fail-once`: es como lo escribe la guía.
    variant = args[:variant].to_s.delete_prefix("--").presence || "happy"

    result = PipelineWalk.call(code: code, variant: variant, io: $stdout)
    initiative = result.initiative

    puts
    puts "#{initiative.code} · #{initiative.current_stage}/" \
         "#{initiative.current_stage_status}"
    puts "iteration #{initiative.iteration} · " \
         "qa_cycles #{initiative.qa_cycles_consumed}/#{Initiative::MAX_QA_CYCLES}"
    puts Pipeline::Glyph.strip(initiative).join(" ")
    puts "escalada: #{initiative.open_escalation&.reason || '—'}"
  end

  desc "Lista las variantes de matrix:walk_pipeline"
  task walk_variants: :environment do
    PipelineWalk::VARIANTS.each { |name, what| puts format("  %-18s %s", name, what) }
  end

  desc "Reconcilia el registro de artefactos con el bucket"
  task verify_artifacts: :environment do
    report = Artifacts::Verify.call

    puts report
    puts

    {
      "FILA SIN OBJETO · se registró algo que no llegó al bucket" => report.missing_objects,
      "OBJETO SIN FILA · blob huérfano, purgable" => report.orphan_objects,
      "CHECKSUM DISTINTO · alguien tocó el contenido" => report.checksum_mismatches
    }.each do |title, divergences|
      next if divergences.empty?

      puts title
      divergences.each { |divergence| puts "  #{divergence}" }
      puts
    end

    # Sale con código distinto de cero. Un heartbeat que siempre sale 0 no sirve
    # para nada: nadie mira la salida de una tarea que nunca falla.
    abort "#{report.divergences.size} divergencias" if report.divergences?

    puts "Sin divergencias."
  end
end
