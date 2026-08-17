# El visor de artefactos: los dos modos que no son `rendered`.
module ArtifactsHelper
  Numbered = Data.define(:number, :text)

  # El markdown crudo con su numeración. La maqueta la enseña arrancando en la
  # 61 porque está recortada; aquí la numeración es real y el panel tiene su
  # propio scroll.
  #
  # Se numera el DOCUMENTO, con su front-matter: es literalmente lo que hay en
  # el bucket, y enseñar otra cosa en un modo que se llama «source» sería
  # mentir. Además hace visible la cabecera, que es lo que permite a cualquiera
  # sacar un artefacto y saber qué es sin preguntarle a matrix.
  def source_lines(artifact)
    return [] if artifact.blank?

    (artifact.document || "").lines.each_with_index.map do |text, index|
      Numbered.new(number: index + 1, text: text.chomp)
    end
  end

  # El tono de cada línea de un diff. Los colores son los de los glifos: verde
  # lo que entra, terracota lo que sale — el mismo idioma que el resto.
  DIFF_TONES = {
    add: "bg-[rgba(74,122,58,.12)] text-terminal-fg",
    del: "bg-[rgba(201,128,112,.12)] text-terminal-fg-3",
    keep: "text-terminal-fg-4"
  }.freeze

  DIFF_MARKS = { add: "+", del: "−", keep: " " }.freeze

  def diff_line_class(line) = DIFF_TONES.fetch(line.op)
  def diff_line_mark(line) = DIFF_MARKS.fetch(line.op)

  # El enlace a un modo del visor, conservando qué artefacto y qué versión se
  # está mirando. Todo por GET: esta pantalla no escribe nada.
  def viewer_mode_link(label, mode:, initiative:, artifact:, current:, **options)
    if artifact.blank?
      return tag.span(label, class: "text-terminal-disabled cursor-not-allowed",
                            title: "no hay artefacto que enseñar")
    end

    return tag.span(label, class: "text-antique-gold") if current == mode

    link_to label,
            client_initiative_path(initiative.platform_client, initiative,
                                   artifact: artifact.code,
                                   version: artifact.version, view: mode),
            **options
  end
end
