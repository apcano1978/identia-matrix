# El eje de MEMORIA. Un repositorio de código: acumula los evolutivos que lo han
# tocado, sus ADR y su historia. No tiene pipeline ni estado — eso es del otro
# eje, y confundirlos es el error del que nace la mitad del diseño de F2.
#
# La palabra «repositorio» significa siempre esto, nunca un proyecto de
# platform ni un evolutivo.
class Repository < ApplicationRecord
  belongs_to :platform_client, class_name: "Platform::Client"

  has_many :initiative_repositories, dependent: :destroy
  has_many :initiatives, through: :initiative_repositories
  has_many :adrs, dependent: :destroy
  has_many :citations, dependent: :nullify
  has_many :ci_checks, dependent: :destroy
  has_many :work_package_repositories, dependent: :destroy

  validates :name, presence: true,
                   uniqueness: { scope: :platform_client_id },
                   format: { with: /\A[a-z0-9]+(?:[-_.][a-z0-9]+)*\z/ }
  validates :default_branch, presence: true

  # Nulo significa «este repositorio no admite verificación automática», y así
  # se dice en su ficha en vez de fingir que verifica. Lo consulta SERAPH (F10).
  def ci_configured? = ci_provider.present? && ci_repo_slug.present?

  def to_s = name
end
