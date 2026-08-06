# frozen_string_literal: true

# La matriz evolutivo × repositorio: la pantalla que explica el modelo, y la que
# más fácil es estropear.
module ClientsHelper
  # Tres columnas fijas, una por repositorio, y dos de cola. Es la ÚNICA
  # retícula que no puede vivir en el CSS: sus columnas centrales son tantas
  # como repositorios tenga el cliente, y eso solo se sabe en tiempo de render.
  def matrix_columns(repositories)
    ([ "20px", "62px", "1fr" ] + ([ "108px" ] * repositories.size) +
      [ "150px", "84px" ]).join(" ")
  end

  # La regla de color de la celda, que es sutil y se pierde sola:
  #
  #   ● oro    lo toca y sigue vivo
  #   ● verde  lo tocó y ya cerró
  #   ·        no lo toca — casi invisible sobre el fondo, a propósito
  #
  # El punto apagado no es decorativo: es lo que hace legible de un vistazo que
  # los dos ejes no son una jerarquía. Si todas las celdas tuvieran peso, la
  # matriz parecería una tabla de datos en lugar de un cruce.
  def matrix_cell(initiative, repository)
    unless initiative.repositories.include?(repository)
      return tag.span("·", class: "text-t12 text-terminal-void")
    end

    colour = initiative.at_publication? ? "text-glyph-done" : "text-antique-gold"
    tag.span("●", class: "text-t12 #{colour}",
                  title: "#{initiative.code} toca #{repository.name}")
  end

  def multi_repo_note(multi, total)
    "#{multi} de #{total} #{'evolutivo'.pluralize(total)} " \
      "#{multi == 1 ? 'toca' : 'tocan'} más de un repositorio"
  end

  # El último evolutivo que tocó el repositorio. Es lo que su tarjeta enseña:
  # un repositorio no tiene estado propio, pero sí una última vez.
  def last_touch(repository)
    repository.initiatives.max_by { |i| i.stage_changed_at || i.opened_at }
  end

  # Solo el CARGO, nunca el nombre. La regla de cero PII de platform se queda
  # intacta: la maqueta pone «marta.roldan · cto» y eso no cruza la frontera.
  def client_contact(client)
    client.primary_contact_role.presence&.then { |role| "contacto · #{role}" }
  end
end
