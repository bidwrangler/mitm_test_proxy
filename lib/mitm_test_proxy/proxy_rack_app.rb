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
        if stub.url == env.fetch("REQUEST_URI")
          headers = {}
          headers["content-type"] = "text/plain"
          body = stub.text

          return [200, headers, [body]]
        end
      end

      super(env)
    end

    private

    def handle_connect(env)
      hijack = env.fetch('rack.hijack')
      client_socket = hijack.call
      raise "#{env.fetch('REQUEST_URI')}"

      ssl_socket = setup_ssl_socket(client_socket)
      ssl_socket.accept

      # Process the request over the SSL socket
      process_request(ssl_socket)

      [200, {}, []] # Return a successful response
    end

    def setup_ssl_socket(client_socket)


      ssl_context = OpenSSL::SSL::SSLContext.new
      ssl_context.cert = OpenSSL::X509::Certificate.new(File.read("path/to/cert.pem"))
      ssl_context.key = OpenSSL::PKey::RSA.new(File.read("path/to/key.pem"))

      OpenSSL::SSL::SSLSocket.new(client_socket, ssl_context).tap do |socket|
        socket.sync_close = true
      end
    end

    def handle_socket_request(socket, rack_app)
      request = WEBrick::HTTPRequest.new(WEBrick::Config::HTTP)
      request.parse(socket)

      env = {
        "REQUEST_METHOD" => request.request_method,
        "SCRIPT_NAME" => "",
        "PATH_INFO" => request.path,
        "QUERY_STRING" => request.query_string,
        "SERVER_NAME" => "localhost",
        "SERVER_PORT" => "80",
        "rack.input" => StringIO.new(request.body.to_s),
        # ... additional Rack env variables as needed
      }

      status, headers, body = rack_app.call(env)

      response = WEBrick::HTTPResponse.new(WEBrick::Config::HTTP)
      response.status = status
      response.body = body.join
      headers.each { |key, value| response[key] = value }
      response.send_response(socket)
    end
  end
end
