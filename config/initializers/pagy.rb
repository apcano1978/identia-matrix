require "pagy/extras/overflow"

# La maqueta corta los listados a propósito ("… 4 criterios más", "+ 2 más").
# 25 por página es el mismo valor que usa identia-platform.
Pagy::DEFAULT[:limit] = 25
Pagy::DEFAULT[:overflow] = :last_page
Pagy::DEFAULT.freeze
