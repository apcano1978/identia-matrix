class Current < ActiveSupport::CurrentAttributes
  attribute :session
  delegate :platform_user, to: :session, allow_nil: true

  alias_method :user, :platform_user
end
