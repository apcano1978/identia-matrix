# El cruce de los dos ejes: una celda de la matriz evolutivo × repositorio.
#
# Aquí se impone la frontera de cliente (invariante 10). Un evolutivo de un
# cliente no puede tocar el repositorio de otro, y eso es una restricción del
# MODELO, no un filtro de vista: es obligación contractual y una vista se puede
# esquivar con una consola.
class InitiativeRepository < ApplicationRecord
  belongs_to :initiative
  belongs_to :repository

  validates :repository_id, uniqueness: { scope: :initiative_id }
  validate :repository_belongs_to_same_client

  before_create :stamp_first_linked_at

  # Anclado: todo lo que el evolutivo cite de este repositorio habla de este
  # estado del código.
  def pinned? = pinned_sha.present?

  private
    def repository_belongs_to_same_client
      return if initiative.blank? || repository.blank?
      return if initiative.platform_client_id == repository.platform_client_id

      errors.add(:repository,
                 "pertenece a otro cliente: la frontera de cliente es dura")
    end

    def stamp_first_linked_at
      self.first_linked_at ||= Time.current
    end
end
