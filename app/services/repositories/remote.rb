# Dónde vive un repositorio, sacado de su `remote_url`.
#
# Matrix lee el código **por la API del proveedor**, así que necesita tres cosas
# de esa URL: el host, el dueño y el nombre. Las dos formas que se usan en el
# mundo real dicen lo mismo de maneras distintas:
#
#   git@github.com:identia/evalora-core.git
#   https://github.com/identia/evalora-core
#
# El `.git` final es opcional en las dos y no forma parte del nombre.
module Repositories::Remote
  Location = Data.define(:host, :owner, :name) do
    def slug = "#{owner}/#{name}"
    def to_s = "#{host}:#{slug}"
  end

  # `git@host:owner/name(.git)` · `scheme://host/owner/name(.git)`
  SSH   = %r{\A(?:[\w.-]+@)?(?<host>[\w.-]+):(?<owner>[\w.-]+)/(?<name>[\w.-]+?)(?:\.git)?\z}
  HTTPS = %r{\Ahttps?://(?:[^@/]+@)?(?<host>[\w.-]+)/(?<owner>[\w.-]+)/(?<name>[\w.-]+?)(?:\.git)?\z}

  module_function

  # `nil` cuando la URL no se entiende, y eso NO es un error a gritos: un
  # repositorio sin `remote_url` legible simplemente no se puede indexar, y su
  # ficha lo dirá — la misma forma que tiene el CI de decir que no verifica.
  def parse(remote_url)
    url = remote_url.to_s.strip
    match = HTTPS.match(url) || SSH.match(url)
    return nil if match.nil?

    Location.new(host: match[:host].downcase, owner: match[:owner], name: match[:name])
  end
end
