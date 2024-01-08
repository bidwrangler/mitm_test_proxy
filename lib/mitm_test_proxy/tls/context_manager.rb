module MitmTestProxy
  # create and manage TLS contexts
  class ContextManager
    def initialize
      @domain_certs = {}
      @mutex = Mutex.new
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

      unless @domain_certs.key?(domain)
        @domain_certs[domain] = create_certificate_for(domain)
      end

      return @domain_certs[domain]
    end

    # create certificate for domain, threadsafe
    def create_certificate_for(domain)
      @mutex.synchronize do
        ca = ::MitmTestProxy.certificate_authority.cert
        cert = ::MitmTestProxy::Certificate.new(domain)
        chain = ::MitmTestProxy::CertificateChain.new(domain, cert.cert, ca)

        return {
          private_key_file: cert.key_file,
          cert_chain_file: chain.file,
        }
      end
    end
  end
end
