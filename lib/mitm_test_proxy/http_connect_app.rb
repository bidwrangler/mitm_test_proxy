# frozen_string_literal: true

module MitmTestProxy
  # handle CONNECT requests, which are used for HTTPS connections through a proxy, then forward
  # the request to the `child_app`.  Non-CONNECT requests are forwarded to the `child_app` as well.
  class HttpConnectApp
    def initialize(child_app)
      @child_app = child_app
    end

    def log(msg)
      return unless ::MitmTestProxy.config.log_requests
      puts msg
    end

    def call(env)
      if env.fetch('REQUEST_METHOD') == 'CONNECT'
        log("MitmTestProxy handling CONNECT request: #{env.fetch('REQUEST_URI')}")
        return handle_connect(env)
      end

      @child_app.call(env)
    end

    private

    def handle_connect(env)
      hijack = env.fetch('rack.hijack')
      client_socket = hijack.call
      client_socket.write("HTTP/1.1 200 Connection Established\r\n\r\n")

      hostname = env.fetch('REQUEST_URI').split(':').first
      begin
        ssl_socket = setup_ssl_socket(hostname, client_socket)

        ssl_socket.accept

        loop do
          parser = Puma::HttpParser.new

          request_env = {}
          while !parser.finished?
            begin
              buffer = ssl_socket.readpartial(1024)
            rescue EOFError
              break
            end
            parser.execute(request_env, buffer, 0)
          end

          break if request_env.length == 0

          request_env["REQUEST_URI"] = "https://#{hostname}#{request_env.fetch('REQUEST_URI')}"

          response = Rack::Chunked.new(@child_app).call(request_env)

          write_response_to(ssl_socket, response)
        end
      rescue Errno::ECONNRESET => error
        # Client closed the connection
      rescue => error
        response = [500, {}, [error.message]]
        log("MitmTestProxy Error: #{error.inspect}, #{error.backtrace.join("\n")}")
        write_response_to(ssl_socket, response)
      end

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

    # TODO move to another class
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

    # TODO move to another class
    def setup_ssl_socket(hostname, client_socket)
      keys = ::MitmTestProxy.certificate_authority.keys_for(hostname)

      key = OpenSSL::PKey::RSA.new(File.read(keys[:private_key_file]))
      certs = load_certificate_chain(keys[:cert_chain_file])

      ssl_context = OpenSSL::SSL::SSLContext.new
      ssl_context.min_version = OpenSSL::SSL::TLS1_2_VERSION

      ssl_context.add_certificate(certs[0], key, certs[1..])

      OpenSSL::SSL::SSLSocket.new(client_socket, ssl_context).tap do |socket|
        socket.sync_close = true
      end
    end
  end
end
