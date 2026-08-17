# GATE 1 · nada se ejecuta sin tu firma.
#
# Una sola vista con DOS ESTADOS, según haya firma o no. No son dos pantallas:
# es la misma, y lo que cambia es si estás delante de una decisión o delante de
# un registro de una decisión ya tomada.
class Gate1Controller < ApplicationController
  include InitiativeScoped

  def show
    @package = @initiative.work_packages.sealed.order(:sealed_at).last
    return redirect_after(initiative_path_for, alert: no_package) if @package.blank?

    @signature = @package.gate_signature

    # Firmado, los commits salen de la FIRMA —congelados—. Sin firmar, del
    # paquete y del ancla del evolutivo: lo que se firmaría si se firmara ahora.
    @commits = @signature ? @signature.commits_in_deploy_order : pending_commits
    @may_sign = GatePolicy.new(Current.user, @initiative).sign?
    @preconditions = preconditions
  end

  private
    # Lo que se sellaría. Se compone aquí y no en la vista para que las dos
    # ramas —firmado y sin firmar— le den a la plantilla la misma forma:
    # repositorio, sha y alcance.
    Pending = Data.define(:repository, :base_sha, :write_scope, :deploy_order)

    def pending_commits
      pinned = @initiative.initiative_repositories
                          .index_by(&:repository_id)

      @package.deploy_sequence.map do |row|
        Pending.new(repository: row.repository,
                    base_sha: pinned[row.repository_id]&.pinned_sha ||
                              row.repository.head_sha || "sin anclar",
                    write_scope: row.write_scope,
                    deploy_order: row.deploy_order)
      end
    end

    def no_package
      "#{@initiative.code} todavía no tiene paquete sellado: lo sella TRINITY."
    end

    # Las tres primeras las comprueba el sistema. La cuarta es un aviso
    # etiquetado `tu criterio`: no bloquea, pero se firma con él delante.
    def preconditions
      dod = current_dod

      [
        { text: "El DoD está revisado por MORFEO",
          met: dod&.reviewed? || false, checked_by: :system },
        { text: "El paquete declara su secuencia de despliegue",
          met: @package.deploy_order_complete?, checked_by: :system },
        { text: "Cada repositorio del paquete tiene su alcance de escritura",
          met: @package.work_package_repositories.all? { |r| r.write_scope.present? },
          checked_by: :system },
        { text: "Has leído qué se va a ejecutar y sobre qué commits",
          met: nil, checked_by: :judgement }
      ]
    end
end
