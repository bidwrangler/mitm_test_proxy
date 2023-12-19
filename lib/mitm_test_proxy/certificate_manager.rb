# frozen_string_literal: true

require 'certificate_authority'

module MitmTestProxy
  # Create Certificate Authority and Certificates for TLS interception
  class CertificateManager
    def initialize(certificate_path)
      @certificate_path = certificate_path
    end

    def get_certificates(domain)
    end

    def create_certificate(domain)
    end

    def create_certificate_authority
      root = CertificateAuthority::Certificate.new
      root.subject.common_name= "http://mitm-test-proxy"
      root.serial_number.number=1
      root.key_material.generate_key
      root.signing_entity = true
      signing_profile = {"extensions" => {"keyUsage" => {"usage" => ["critical", "keyCertSign"] }} }
      root.sign!(signing_profile)

      puts root.key_material.private_key.to_pem
      puts root.key_material.public_key.to_pem
    end
  end
end
