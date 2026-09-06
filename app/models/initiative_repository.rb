# El cruce de los dos ejes: una celda de la matriz evolutivo × repositorio.
#
# Aquí se impone la frontera de proyecto (invariante 10). Un evolutivo no puede
# tocar el repositorio de otro proyecto, y eso es una restricción del MODELO, no
# un filtro de vista: es obligación contractual y una vista se puede esquivar con
# una consola.
#
# Desde F11 la frontera es el proyecto y no el cliente, y es MÁS ESTRECHA: dos
# proyectos del mismo cliente tampoco pueden prestarse repositorios.
class InitiativeRepository < ApplicationRecord
  belongs_to :initiative
  belongs_to :repository

  validates :repository_id, uniqueness: { scope: :initiative_id }
  validate :repository_belongs_to_same_project

  before_create :stamp_first_linked_at

  # Anclado: todo lo que el evolutivo cite de este repositorio habla de este
  # estado del código.
  def pinned? = pinned_sha.present?

  private
    def repository_belongs_to_same_project
      return if initiative.blank? || repository.blank?
      return if initiative.project_id == repository.project_id

      errors.add(:repository,
                 "pertenece a otro proyecto: la frontera de proyecto es dura")
    end

    def stamp_first_linked_at
      self.first_linked_at ||= Time.current
    end
end
