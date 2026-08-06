# Reconstruye `initiatives.current_stage` desde las `stage_entries`.
#
# El caché solo es defendible si se puede recomputar. Existe aquí y no dentro de
# la tarea rake para que un test pueda comprobar que lo reconstruido coincide
# con lo que dejaron las transiciones — que es la única prueba de que el caché
# no ha derivado.
module StageCache
  Change = Data.define(:initiative, :from, :to)

  module_function

  # La etapa en la que está el evolutivo según su historial: la última fila sin
  # cerrar. Si todas están cerradas —el evolutivo terminó— vale la última.
  def derive(initiative)
    entries = initiative.stage_entries.to_a
    return nil if entries.empty?

    open = entries.select { |e| e.exited_at.nil? }
    entry = (open.presence || entries).max_by { |e| [ e.iteration, e.position ] }

    [ entry.stage, entry.status ]
  end

  # Devuelve los cambios aplicados. Vacío significa que el caché estaba al día.
  def rebuild(scope = Initiative.all)
    scope.includes(:stage_entries).filter_map do |initiative|
      derived = derive(initiative)
      next if derived.nil?

      stage, status = derived
      next if initiative.current_stage == stage &&
              initiative.current_stage_status == status

      from = "#{initiative.current_stage}/#{initiative.current_stage_status}"
      initiative.update!(current_stage: stage, current_stage_status: status)

      Change.new(initiative: initiative, from: from, to: "#{stage}/#{status}")
    end
  end
end
