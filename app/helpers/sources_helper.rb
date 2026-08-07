# La pantalla de fuentes.
#
# `also_in` vive aquí y no se llama a `Sources::Scope` desde la plantilla porque
# dentro de una vista `Sources` resuelve contra `ActionView::Template::Sources`,
# que existe y no es lo nuestro. Un `::Sources::Scope` lo arreglaría, pero un
# helper dice mejor lo que hace.
module SourcesHelper
  # Los OTROS evolutivos que también acotan esta fuente. Es lo que produce el
  # «también en ev-014», y con ello la prueba en pantalla de que el ámbito es un
  # filtro y no posesión: un documento vive una sola vez.
  def also_in(shared, source)
    Sources::Scope.also_in(shared, source)
  end

  # El indexado de un repositorio, tal y como lo enseña la tabla.
  def indexed_files(repository)
    return "sin indexar" if repository.files_count.blank?

    "#{number_with_delimiter(repository.files_count)} fich."
  end

  # La forma exacta que hay que escribir para citar este repositorio. Es
  # didáctica a propósito: la pantalla enseña a citar, no solo qué hay.
  def citation_prefix(repository) = "[src:code/#{repository.name}:…]"
end
