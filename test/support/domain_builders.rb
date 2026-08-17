# Constructores mínimos para los tests de dominio.
#
# No hay fixtures del dominio a propósito: el grafo de F2 es profundo —un
# veredicto cuelga de un informe, de un DoD, de un evolutivo y de un cliente— y
# un fichero de fixtures que lo cubriera entero sería más difícil de leer que la
# tabla que describe. El seed de la maqueta (bloque D) es otra cosa: ese existe
# para MIRARLO.
module DomainBuilders
  def self.included(base) = base.extend(self)

  # El slug lleva sufijo salvo que el test pida uno concreto: es único a nivel
  # de tabla y varios constructores crean cliente por su cuenta.
  def build_client(slug: nil, **attributes)
    slug ||= "cliente-#{next_platform_id}"

    Platform::Record.writing do
      Platform::Client.create!(
        platform_id: next_platform_id, slug: slug, name: slug.titleize,
        **attributes)
    end
  end

  def build_platform_user(role: :admin, **attributes)
    Platform::Record.writing do
      Platform::User.create!(
        platform_id: next_platform_id,
        email_address: attributes.delete(:email_address) ||
                       "user#{next_platform_id}@identiaconsulting.com",
        name: "Persona", role: role, **attributes)
    end
  end

  def build_document(client: nil, slug: nil, **attributes)
    Platform::Record.writing do
      Platform::Document.create!(
        platform_id: next_platform_id,
        platform_client: client || build_client,
        slug: slug || "doc-#{next_platform_id}",
        title: "Un documento", **attributes)
    end
  end

  def build_meeting(client: nil, slug: nil, held_on: Date.new(2026, 5, 2), **attributes)
    Platform::Record.writing do
      Platform::Meeting.create!(
        platform_id: next_platform_id,
        platform_client: client || build_client,
        slug: slug || "reunion-#{next_platform_id}",
        title: "Una reunión", held_on: held_on, **attributes)
    end
  end

  def build_repository(client: nil, name: "identia-platform", **attributes)
    Repository.create!(platform_client: client || build_client, name: name,
                       **attributes)
  end

  def build_initiative(client: nil, code: nil, **attributes)
    Initiative.create!(
      platform_client: client || build_client,
      code: code || "ev-#{format('%03d', next_platform_id % 1000)}",
      title: "Un evolutivo", opened_at: Time.current, **attributes)
  end

  def build_dod(initiative: nil, **attributes)
    initiative ||= build_initiative
    DefinitionOfDone.create!(initiative: initiative,
                             code: "dod-#{initiative.number}", **attributes)
  end

  def build_criterion(dod: nil, key: nil, **attributes)
    dod ||= build_dod
    DodCriterion.create!(
      definition_of_done: dod, key: key || "c#{dod.dod_criteria.count}",
      statement: "Se cumple algo comprobable", **attributes)
  end

  def build_report(dod: nil, outcome: :conforme, **attributes)
    dod ||= build_dod
    VerificationReport.create!(
      initiative: dod.initiative, definition_of_done: dod,
      code: "verify-#{dod.initiative.number}-#{next_platform_id}",
      outcome: outcome, **attributes)
  end

  def build_run(initiative: nil, agent: :seraph, purpose: "dod_pass", **attributes)
    initiative ||= build_initiative

    AgentRun.create!(initiative: initiative, agent: agent, purpose: purpose,
                     code: "#{agent}/run-#{next_platform_id}", status: :ok,
                     **attributes)
  end

  # Una fila de artefacto SIN BYTES, a propósito: casi ningún test los quiere, y
  # meter una escritura de disco en cada uno encarece la suite sin comprar nada.
  # Además hay tests que necesitan justo esto —una fila sin objeto es la primera
  # divergencia que busca Artifacts::Verify—.
  #
  # Para un artefacto con bytes de verdad, `publish_artifact`.
  def build_artifact(initiative: nil, kind: :dod, version: 1, **attributes)
    initiative ||= build_initiative
    code = Artifacts::Key.code(kind: kind, number: initiative.number)

    Artifact.create!(
      initiative: initiative, platform_client: initiative.platform_client,
      kind: kind, code: code, version: version,
      storage_key: Artifacts::Key.build(
        client: initiative.platform_client.slug,
        initiative: initiative.code, code: code, version: version),
      checksum: "sha256:#{SecureRandom.hex(8)}", **attributes)
  end

  # Un artefacto de verdad: por el único camino que hay, con sus bytes y su
  # front-matter. Para lo que no necesite bytes, `build_artifact`.
  def publish_artifact(initiative: nil, kind: :dod, body: "# Un artefacto\n", **options)
    initiative ||= build_initiative

    Artifacts::Publish.call(
      initiative: initiative, kind: kind, body: body,
      produced_at: Time.zone.parse("2026-05-02 10:00"),
      produced_by_run: options.delete(:produced_by_run) ||
                       build_run(initiative: initiative),
      **options).artifact
  end

  # Coloca un evolutivo en una etapa sin recorrer el pipeline entero, con su
  # fila: en producción la fila de la etapa en la que estás siempre existe.
  def place(initiative, stage, status: :active)
    initiative.update!(current_stage: stage, current_stage_status: status,
                       stage_changed_at: Time.current)
    # Cerrando lo que hubiera abierto: una sola etapa a la vez es el invariante
    # 11, y un helper que lo rompa hace fallar tests que están bien.
    initiative.stage_entries.where(exited_at: nil)
              .where.not(stage: Initiative.current_stages[stage])
              .update_all(status: StageEntry.statuses[:done],
                          exited_at: Time.current)
    initiative.stage_entries.find_or_create_by!(
      stage: stage, iteration: initiative.iteration
    ) do |entry|
      entry.status = status
      entry.qa_cycle = initiative.qa_cycles_consumed
      entry.entered_at = Time.current
    end
    initiative
  end

  def build_note(initiative, author: nil)
    HumanNote.create!(
      initiative: initiative,
      platform_client_id: initiative.platform_client_id,
      author_user: author || build_platform_user,
      code: "2026-08-05-ap#{next_platform_id}",
      body: "Lo que cambió antes de reanudar.")
  end

  # Los platform_id tienen que ser únicos y estables dentro de un test, y los
  # tests corren en paralelo: un contador de clase no vale.
  def next_platform_id
    @next_platform_id = (@next_platform_id || 0) + 1
    (Process.pid % 10_000) * 1_000 + @next_platform_id
  end
end

class ActiveSupport::TestCase
  include DomainBuilders
end
