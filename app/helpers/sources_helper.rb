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

  # ── Marcar el ámbito (F12 · B5) ──────────────────────────────────────────

  # En qué array del formulario va cada fuente.
  #
  # ⚠ TRES ARRAYS PLANOS y no un `Tipo-id` compuesto. El tipo no sale nunca de un
  # parámetro, así que no hay nada que `constantize` de lo que llegue de fuera: el
  # controlador consulta tres colecciones acotadas al proyecto y ya está.
  SOURCE_FIELDS = {
    "ProjectDocument" => "project_document_ids[]",
    "Platform::Document" => "platform_document_ids[]",
    "Platform::Meeting" => "meeting_ids[]"
  }.freeze

  def source_field(source) = SOURCE_FIELDS.fetch(source.class.name)

  # Marcada de fábrica: lo CITABLE. Un documento sin cuerpo extraído no viajaría
  # al agente de todos modos —`Runtime::Request` filtra por `citable?`— así que
  # ofrecerlo marcado prometería algo que no ocurre.
  #
  # Es la misma regla que usa `Initiatives::Open#scope_sources` para decidir si
  # alguien recortó de verdad. Las dos tienen que decir lo mismo o la pantalla
  # miente sobre lo que va a pasar.
  def source_checked_by_default?(source) = source.citable?

  # De dónde viene y cuánto se la ha citado, en una línea.
  #
  # Las referencias solo cuando las hay: `refs_count` hoy solo lo siembra el
  # catálogo, así que un «0 refs» en todo lo demás sería ruido con aspecto de
  # dato. La maqueta las enseña en tres de cinco filas, y por lo mismo.
  def source_origin(source, refs: 0)
    parts = [ source.is_a?(ProjectDocument) ? "◆ del proyecto" : "◆ origen" ]
    parts << "#{refs} #{'ref'.pluralize(refs)}" if refs.positive?
    parts << "sin cuerpo extraído" unless source.citable?
    parts.join(" · ")
  end
end
