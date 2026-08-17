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
