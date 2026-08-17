# frozen_string_literal: true

module Gates
  # GATE 1 · nada se ejecuta sin una firma.
  #
  # Es la escritura más seria del sistema: irreversible, nominal, y autoriza a
  # Claude Code a escribir sobre repositorios de un cliente. Por eso exige
  # **re-autenticación con contraseña** aunque haya sesión abierta: la fricción
  # es proporcionada a lo que se autoriza, y una sesión olvidada en un portátil
  # no debería poder firmar.
  #
  # Lo que la firma SELLA se copia aquí, y a partir de entonces es
  # autosuficiente: identidad, hora, hash del paquete y **una fila por
  # repositorio implicado**. Aunque el paquete se vuelva a sellar más tarde, lo
  # que se autorizó queda como estaba — que es la razón de existir de un
  # registro de firma.
  class Sign
    class Refused < StandardError; end

    Result = Data.define(:signature, :initiative)

    def self.call(...) = new(...).call

    def initialize(initiative:, user:, password:)
      @initiative = initiative
      @user = user
      @password = password
    end

    def call
      package = sealed_package
      refuse!("no hay ningún paquete sellado que firmar") if package.blank?
      refuse!("#{package.code} ya está firmado") if package.signed?
      refuse_incomplete_sequence!(package)
      refuse_bad_password!

      signature = ApplicationRecord.transaction do
        created = create_signature(package)
        seal_commits(created, package)
        created
      end

      # Fuera de la transacción: avanzar escribe su propio evento y su propia
      # entrada de etapa, y `Advance` ya exige que la firma cubra el paquete.
      Pipeline::Advance.call(initiative: @initiative, actor: signature.identity)

      Result.new(signature: signature, initiative: @initiative.reload)
    end

    private
      def sealed_package
        @initiative.work_packages.sealed.order(:sealed_at).last
      end

      # Un multi-repo sin una fila de commit por repositorio no se puede firmar:
      # firmar sin saber en qué orden se despliega es autorizar una ventana de
      # convivencia a ciegas. Lo valida también `GateSignature`; aquí se
      # comprueba antes para poder decirlo con un mensaje que se entienda.
      def refuse_incomplete_sequence!(package)
        return if package.deploy_order_complete?

        refuse!("#{package.code} no declara su secuencia de despliegue")
      end

      # La contraseña se verifica contra la MISMA fuente que el login, no contra
      # una comprobación aparte: dos formas de validar una credencial acaban
      # discrepando.
      def refuse_bad_password!
        outcome = Auth.authenticate(email_address: @user.email_address,
                                    password: @password)
        return if outcome.ok? && outcome.user == @user

        refuse!("la contraseña no es correcta")
      end

      def create_signature(package)
        GateSignature.create!(
          initiative: @initiative, work_package: package,
          package_hash: package.content_hash,
          signed_by_user: @user,
          # La identidad se CONGELA. Si mañana esta persona cambia de cargo o
          # desaparece de platform, el registro sigue diciendo quién firmó.
          identity: @user.identity_snapshot,
          signed_at: Time.current,
          statement: statement_for(package))
      end

      # La frase la compone el SISTEMA, no el firmante: lo que se firma es una
      # afirmación concreta sobre un paquete y unos repositorios, no un «acepto»
      # genérico que no dice nada.
      def statement_for(package)
        repositories = package.repositories.count
        window = package.multi_repo? ? " y asumí la ventana de despliegue" : ""

        "Firmé la entrega de #{package.code.upcase} a Claude Code sobre " \
          "#{pluralize_repositories(repositories)}#{window}."
      end

      def pluralize_repositories(count)
        count == 1 ? "un repositorio" : "#{count} repositorios"
      end

      # El `base_sha` sale del ANCLA del evolutivo, no de la cabeza del
      # repositorio: se firma sobre el commit contra el que se trabajó.
      def seal_commits(signature, package)
        package.deploy_sequence.each do |row|
          GateSignatureCommit.create!(
            gate_signature: signature, repository: row.repository,
            base_sha: pinned_sha(row.repository),
            write_scope: row.write_scope, deploy_order: row.deploy_order)
        end
      end

      def pinned_sha(repository)
        link = @initiative.initiative_repositories
                          .find { |row| row.repository_id == repository.id }

        link&.pinned_sha || repository.head_sha || "0000000"
      end

      def refuse!(reason) = raise(Refused, reason)
  end
end
