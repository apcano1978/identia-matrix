# frozen_string_literal: true

# Base de autorización. Deniega por defecto: en F0 todavía no hay roles ni
# recursos, y una policy permisiva por omisión es justo lo que no queremos en
# un sistema cuya frontera de cliente es obligación contractual.
#
# Los roles (approver / observer) llegan en F2, y con ellos los predicados
# semánticos en User de los que colgarán estas policies — misma convención que
# identia-platform (User#back_office_access? y compañía).
class ApplicationPolicy
  attr_reader :user, :record

  def initialize(user, record)
    @user = user
    @record = record
  end

  def index? = false
  def show? = false
  def create? = false
  def new? = create?
  def update? = false
  def edit? = update?
  def destroy? = false

  class Scope
    def initialize(user, scope)
      @user = user
      @scope = scope
    end

    def resolve = scope.none

    private

    attr_reader :user, :scope
  end
end
