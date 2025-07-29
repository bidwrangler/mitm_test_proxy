module MitmTestProxy
  # create and manage TLS contexts
  class ContextManager
    def initialize
      @domain_certs = {}
      @mutex = Mutex.new
      @cleanup_scheduled = false
    end

    def load_certificate_chain(filepath)
      if OpenSSL::X509::Certificate.method_defined?(:load_file)
        # ruby 3
        return OpenSSL::X509::Certificate.load_file(filepath)
      end
      # ruby 2
      certificate_chain = File.read(filepath)
      certificates = certificate_chain.scan(/-----BEGIN CERTIFICATE-----.+?-----END CERTIFICATE-----/m)
      certs = certificates.map { |cert| OpenSSL::X509::Certificate.new(cert) }
    end

    def setup_ssl_socket(hostname, client_socket)
      keys = keys_for(hostname)

      key = OpenSSL::PKey::RSA.new(File.read(keys[:private_key_file]))
      certs = load_certificate_chain(keys[:cert_chain_file])

      ssl_context = OpenSSL::SSL::SSLContext.new
      ssl_context.min_version = OpenSSL::SSL::TLS1_2_VERSION

      ssl_context.add_certificate(certs[0], key, certs[1..])

      OpenSSL::SSL::SSLSocket.new(client_socket, ssl_context).tap do |socket|
        socket.sync_close = true
      end
    end

    # find or create certificates for hostname
    def keys_for(hostname)
      domain = hostname.split(':').first

      @mutex.synchronize do
        unless @domain_certs.key?(domain)
          @domain_certs[domain] = create_certificate_for(domain)
        end

        return @domain_certs[domain]
      end
    end

    # create certificate for domain (caller must hold @mutex)
    def create_certificate_for(domain)
      ca = ::MitmTestProxy.certificate_authority.cert
      cert = ::MitmTestProxy::Certificate.new(domain)
      chain = ::MitmTestProxy::CertificateChain.new(domain, cert.cert, ca)

      result = {
        private_key_file: cert.key_file,
        cert_chain_file: chain.file,
      }
      
      # Schedule cleanup if not already done
      schedule_cleanup unless @cleanup_scheduled
      
      return result
    end

    # Clean up certificate files and reset domain certs cache
    def cleanup_certificates
      @mutex.synchronize do
        @domain_certs.each do |domain, cert_info|
          begin
            File.unlink(cert_info[:private_key_file]) if File.exist?(cert_info[:private_key_file])
            File.unlink(cert_info[:cert_chain_file]) if File.exist?(cert_info[:cert_chain_file])
          rescue => e
            # Ignore cleanup errors
          end
        end
        @domain_certs.clear
        @cleanup_scheduled = false
      end
    end

    private

    def schedule_cleanup
      return if @cleanup_scheduled
      @cleanup_scheduled = true
      
      # Schedule cleanup at process exit
      at_exit do
        cleanup_certificates
      end
    end
  end
end
