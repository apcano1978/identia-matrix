# La fuente real: valida la credencial contra identia-platform.
#
# El endpoint es F7 —`POST /internal/v1/sessions`, con cero PII en la
# respuesta: solo el rol— y hasta entonces esto no finge funcionar. Un stub que
# devolviera «no autenticado» sería peor que un error: dejaría creer que la
# integración está y solo falla la contraseña.
module Auth::PlatformSource
  module_function

  def authenticate(email_address:, password:)
    raise NotImplementedError,
          "la autenticación contra platform llega en F7; " \
          "usa MATRIX_AUTH_SOURCE=fake mientras tanto"
  end
end
