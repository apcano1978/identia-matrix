# Active Record Encryption — para cifrar at-rest los secretos que matrix guarda:
# el token de lectura contra identia-platform y, más adelante, las credenciales
# de clonado de los repositorios de cliente (F10).
#
# Claves:
# - PRODUCCIÓN: obligatorias por ENV (secrets de Kamal). Generar con
#     bin/rails db:encryption:init
#   y exportar AR_ENCRYPTION_PRIMARY_KEY / _DETERMINISTIC_KEY / _KEY_DERIVATION_SALT.
# - DEV/TEST: ENV si existe; si no, un fallback fijo NO secreto (los datos cifrados
#   son locales y desechables). Así el entorno funciona sin pasos manuales.
# - BUILD-TIME (assets:precompile con SECRET_KEY_BASE_DUMMY=1): los secrets de Kamal
#   aún no están inyectados (solo existen en runtime). Al compilar assets no se
#   accede a datos cifrados, así que se tratan como dev y el build no exige las
#   claves reales.
Rails.application.configure do
  enc = config.active_record.encryption

  if Rails.env.production? && ENV["SECRET_KEY_BASE_DUMMY"].blank?
    enc.primary_key         = ENV.fetch("AR_ENCRYPTION_PRIMARY_KEY")
    enc.deterministic_key   = ENV.fetch("AR_ENCRYPTION_DETERMINISTIC_KEY")
    enc.key_derivation_salt = ENV.fetch("AR_ENCRYPTION_KEY_DERIVATION_SALT")
  else
    enc.primary_key         = ENV.fetch("AR_ENCRYPTION_PRIMARY_KEY", "dev_ar_primary_key_change_me_32xx")
    enc.deterministic_key   = ENV.fetch("AR_ENCRYPTION_DETERMINISTIC_KEY", "dev_ar_deterministic_key_32xxxxxx")
    enc.key_derivation_salt = ENV.fetch("AR_ENCRYPTION_KEY_DERIVATION_SALT", "dev_ar_key_derivation_salt_32xxxx")
  end
end
