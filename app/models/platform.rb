# La proyección de identia-platform.
#
# El prefijo se declara aquí y no tabla por tabla: con `Platform::Client` sobre
# `clients` a secas, la palabra «cliente» dejaría de decir de dónde viene el
# dato, que es justo lo que este namespace existe para recordar.
module Platform
  def self.table_name_prefix = "platform_"
end
