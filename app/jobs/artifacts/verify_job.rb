# La reconciliación del bucket, como latido.
#
# NO ESCRIBE EN LA BASE DE DATOS, y es deliberado: matrix escribe casi nada —lo
# que puede escribir cabe en una lista blanca, ver
# test/invariants/matrix_writes_almost_nothing_test.rb— y una auditoría que crea
# filas sería una escritura nueva que habría que justificar. Deja el hallazgo en
# el log, que es donde se mira cuando algo va mal.
module Artifacts
  class VerifyJob < ApplicationJob
    queue_as :low

    def perform
      report = Artifacts::Verify.call

      Rails.logger.info("[artifacts] #{report}")
      return unless report.divergences?

      report.divergences.each do |divergence|
        Rails.logger.error("[artifacts] #{divergence.kind} · #{divergence}")
      end
    end
  end
end
