# frozen_string_literal: true

module MitmTestProxy
  # handle CONNECT requests, which are used for HTTPS connections through a proxy, then forward
  # the request to the `child_app`.  Non-CONNECT requests are forwarded to the `child_app` as well.
  class HttpConnectApp
    def initialize(child_app, context_manager)
      @child_app = child_app
      @context_manager = context_manager
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
        ssl_socket = @context_manager.setup_ssl_socket(hostname, client_socket)

        ssl_socket.accept

        # Handle exactly one HTTP request per SSL connection
        # Don't try to handle multiple requests on the same connection
        parser = Puma::HttpParser.new

        request_env = {}
        while !parser.finished?
          begin
            # Use IO.select with timeout to prevent infinite blocking
            if IO.select([ssl_socket], nil, nil, 10)  # 10 second timeout
              buffer = ssl_socket.readpartial(1024)
            else
              # Timeout waiting for data - break out of parser loop
              break
            end
          rescue EOFError
            break
          rescue IO::WaitReadable
            retry
          end
          parser.execute(request_env, buffer, 0)
        end

        if request_env.length > 0
          request_env["REQUEST_URI"] = "https://#{hostname}#{request_env.fetch('REQUEST_URI')}"

          # Get response from child app
          status, headers, body = @child_app.call(request_env)
          
          # Ensure body is properly enumerable for streaming
          if body.respond_to?(:each)
            response = [status, headers, body]
          else
            response = [status, headers, [body.to_s]]
          end

          write_response_to(ssl_socket, response)
        end
        
        # Explicitly close the SSL socket to signal end of connection
        ssl_socket.close rescue nil
      rescue Errno::ECONNRESET => error
        # Client closed the connection
        log("MitmTestProxy Client disconnected: #{hostname}")
      rescue => error
        response = [500, {}, [error.message]]
        log("MitmTestProxy Error: #{error.inspect}, #{error.backtrace.join("\n")}")
        write_response_to(ssl_socket, response) rescue nil
        ssl_socket.close rescue nil
      ensure
        # Always ensure sockets are closed
        ssl_socket.close rescue nil
        client_socket.close rescue nil
      end

      [200, {}, []] # Return a successful response
    end

    def write_response_to(socket, response)
      status, headers, body = response

      # Format the status line
      http_status_line = "HTTP/1.1 #{status} #{Rack::Utils::HTTP_STATUS_CODES[status]}\r\n"

      begin
        # Set socket write timeout to prevent indefinite blocking
        socket.setsockopt(Socket::SOL_SOCKET, Socket::SO_SNDTIMEO, [5, 0].pack("l_2")) if socket.respond_to?(:setsockopt)
        
        socket.write(http_status_line)
        # Format the headers
        http_headers = headers.map { |key, value| "#{key}: #{value}\r\n" }.join
        socket.write(http_headers)
        socket.write("\r\n")

        body.each do |chunk|
          socket.write(chunk)
        end
      rescue Errno::EPIPE, Errno::ECONNRESET, IO::TimeoutError => e
        log("MitmTestProxy Write error (client may have disconnected): #{e.message}")
        # Don't re-raise, just log and continue
      rescue => e
        log("MitmTestProxy Unexpected write error: #{e.message}")
        raise
      end
    end
  end
end
