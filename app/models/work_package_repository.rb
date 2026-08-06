# Un repositorio dentro de un paquete, con su sitio en la secuencia.
#
# El orden importa y por eso es obligatorio: durante el despliegue convive una
# versión nueva con una vieja, y el orden es lo que decide si esa convivencia
# funciona.
class WorkPackageRepository < ApplicationRecord
  belongs_to :work_package
  belongs_to :repository

  validates :repository_id, uniqueness: { scope: :work_package_id }
  validates :deploy_order, presence: true,
                           numericality: { greater_than_or_equal_to: 1 },
                           uniqueness: { scope: :work_package_id }

  scope :in_deploy_order, -> { order(:deploy_order) }
end
