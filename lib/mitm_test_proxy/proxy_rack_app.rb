# frozen_string_literal: true

require 'rack-proxy'

module MitmTestProxy
  class ProxyRackApp < Rack::Proxy
    def initialize(stubs)
      @stubs = stubs
    end

    def call(env)
      if env.fetch('REQUEST_METHOD') == 'CONNECT'
        return handle_connect(env)
      end

      @stubs.each do |stub|
        if stub.match?(env.fetch("REQUEST_URI"))
          return stub.call(env)
        end
      end

      super(env)
    end

    private

    def handle_connect(env)
      hijack = env.fetch('rack.hijack')
      client_socket = hijack.call
      client_socket.write("HTTP/1.1 200 Connection Established\r\n\r\n")

      hostname = env.fetch('REQUEST_URI').split(':').first
      ssl_socket = setup_ssl_socket(hostname, client_socket)

      ssl_socket.accept

      parser = Puma::HttpParser.new

      request_env = {}
      while !parser.finished?
        parser.execute(request_env, ssl_socket.readpartial(1024), 0)
      end

      if request_env.length == 0
        raise "request_env is empty"
      end

      request_env["REQUEST_URI"] = "https://#{hostname}#{request_env.fetch('REQUEST_URI')}"

      response = Rack::Chunked.new(self).call(request_env)

      write_response_to(ssl_socket, response)

      [200, {}, []] # Return a successful response
    end

    def write_response_to(socket, response)
      status, headers, body = response

      # Format the status line
      http_status_line = "HTTP/1.1 #{status} #{Rack::Utils::HTTP_STATUS_CODES[status]}\r\n"

      socket.write(http_status_line)
      # Format the headers
      http_headers = headers.map { |key, value| "#{key}: #{value}\r\n" }.join
      socket.write(http_headers)
      socket.write("\r\n")

      body.each do |chunk|
        socket.write(chunk)
      end
    end

    def setup_ssl_socket(hostname, client_socket)
      keys = certificate_chain(hostname)

      certs = OpenSSL::X509::Certificate.load_file(keys[:cert_chain_file])
      key = OpenSSL::PKey::RSA.new(File.read(keys[:private_key_file]))

      ssl_context = OpenSSL::SSL::SSLContext.new
      ssl_context.add_certificate(certs[0], key, certs[1..])

      OpenSSL::SSL::SSLSocket.new(client_socket, ssl_context).tap do |socket|
        socket.sync_close = true
      end
    end

    def certificate_chain(url)
      domain = url.split(':').first
      ca = ::MitmTestProxy.certificate_authority.cert
      cert = ::MitmTestProxy::Certificate.new(domain)
      chain = ::MitmTestProxy::CertificateChain.new(domain, cert.cert, ca)

      { private_key_file: cert.key_file,
        cert_chain_file: chain.file }
    end
  end
end
