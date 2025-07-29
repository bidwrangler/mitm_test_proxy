# frozen_string_literal: true

require 'mitm_test_proxy/http_connect_app'
require 'mitm_test_proxy/tls/context_manager'
require 'stringio'
require 'timeout'

RSpec.describe MitmTestProxy::HttpConnectApp do
  let(:child_app) { double('child_app') }
  let(:context_manager) { instance_double(MitmTestProxy::ContextManager) }
  let(:app) { described_class.new(child_app, context_manager) }
  
  describe '#initialize' do
    it 'stores the child app and context manager' do
      expect(app.instance_variable_get(:@child_app)).to eq(child_app)
      expect(app.instance_variable_get(:@context_manager)).to eq(context_manager)
    end
  end

  describe '#log' do
    context 'when logging is enabled' do
      before do
        allow(MitmTestProxy.config).to receive(:log_requests).and_return(true)
      end

      it 'outputs the message' do
        expect { app.send(:log, 'test message') }.to output("test message\n").to_stdout
      end
    end

    context 'when logging is disabled' do
      before do
        allow(MitmTestProxy.config).to receive(:log_requests).and_return(false)
      end

      it 'does not output the message' do
        expect { app.send(:log, 'test message') }.not_to output.to_stdout
      end
    end
  end

  describe '#call' do
    let(:env) { { 'REQUEST_METHOD' => 'GET', 'REQUEST_URI' => '/test' } }

    context 'when request is not CONNECT' do
      it 'forwards to child app' do
        expect(child_app).to receive(:call).with(env).and_return([200, {}, ['OK']])
        result = app.call(env)
        expect(result).to eq([200, {}, ['OK']])
      end
    end

    context 'when request is CONNECT' do
      let(:env) { { 'REQUEST_METHOD' => 'CONNECT', 'REQUEST_URI' => 'example.com:443' } }

      before do
        allow(MitmTestProxy.config).to receive(:log_requests).and_return(true)
      end

      it 'logs the CONNECT request' do
        allow(app).to receive(:handle_connect).with(env).and_return([200, {}, []])
        expect { app.call(env) }.to output(/MitmTestProxy handling CONNECT request: example.com:443/).to_stdout
      end

      it 'calls handle_connect' do
        expect(app).to receive(:handle_connect).with(env).and_return([200, {}, []])
        result = app.call(env)
        expect(result).to eq([200, {}, []])
      end
    end
  end

  describe '#write_response_to' do
    let(:mock_socket) { instance_double(Socket) }
    let(:response) { [200, { 'Content-Type' => 'text/plain' }, ['Hello World']] }

    before do
      allow(mock_socket).to receive(:write)
      allow(mock_socket).to receive(:respond_to?).with(:setsockopt).and_return(true)
      allow(mock_socket).to receive(:setsockopt)
    end

    it 'sets socket write timeout to prevent hanging' do
      expect(mock_socket).to receive(:setsockopt)
        .with(Socket::SOL_SOCKET, Socket::SO_SNDTIMEO, [5, 0].pack("l_2"))
      
      app.send(:write_response_to, mock_socket, response)
    end

    it 'writes the HTTP response correctly' do
      expect(mock_socket).to receive(:write).with("HTTP/1.1 200 OK\r\n")
      expect(mock_socket).to receive(:write).with("Content-Type: text/plain\r\n")
      expect(mock_socket).to receive(:write).with("\r\n")
      expect(mock_socket).to receive(:write).with("Hello World")
      
      app.send(:write_response_to, mock_socket, response)
    end

    it 'skips setting socket timeout if socket does not support setsockopt' do
      allow(mock_socket).to receive(:respond_to?).with(:setsockopt).and_return(false)
      expect(mock_socket).not_to receive(:setsockopt)
      
      app.send(:write_response_to, mock_socket, response)
    end

    context 'when socket write fails with EPIPE' do
      before do
        allow(mock_socket).to receive(:write).and_raise(Errno::EPIPE, 'Broken pipe')
        allow(MitmTestProxy.config).to receive(:log_requests).and_return(true)
      end

      it 'logs the error and does not re-raise' do
        expect { app.send(:write_response_to, mock_socket, response) }
          .to output(/MitmTestProxy Write error \(client may have disconnected\): Broken pipe/).to_stdout
        
        expect { app.send(:write_response_to, mock_socket, response) }.not_to raise_error
      end
    end

    context 'when socket write fails with ECONNRESET' do
      before do
        allow(mock_socket).to receive(:write).and_raise(Errno::ECONNRESET, 'Connection reset')
        allow(MitmTestProxy.config).to receive(:log_requests).and_return(true)
      end

      it 'logs the error and does not re-raise' do
        expect { app.send(:write_response_to, mock_socket, response) }
          .to output(/MitmTestProxy Write error \(client may have disconnected\): Connection reset/).to_stdout
        
        expect { app.send(:write_response_to, mock_socket, response) }.not_to raise_error
      end
    end

    context 'when socket write fails with Timeout::Error' do
      before do
        allow(mock_socket).to receive(:write).and_raise(Timeout::Error, 'Timeout')
        allow(MitmTestProxy.config).to receive(:log_requests).and_return(true)
      end

      it 'logs the error and does not re-raise' do
        expect { app.send(:write_response_to, mock_socket, response) }
          .to output(/MitmTestProxy Write error \(client may have disconnected\): Timeout/).to_stdout
        
        expect { app.send(:write_response_to, mock_socket, response) }.not_to raise_error
      end
    end

    context 'when socket write fails with unexpected error' do
      before do
        allow(mock_socket).to receive(:write).and_raise(StandardError, 'Unexpected error')
        allow(MitmTestProxy.config).to receive(:log_requests).and_return(true)
      end

      it 'logs the error and re-raises' do
        expect { app.send(:write_response_to, mock_socket, response) }
          .to output(/MitmTestProxy Unexpected write error: Unexpected error/).to_stdout
          .and raise_error(StandardError, 'Unexpected error')
      end
    end
  end

  describe 'body response validation in handle_connect' do
    let(:mock_hijack) { double('hijack') }
    let(:mock_client_socket) { instance_double(Socket) }
    let(:mock_ssl_socket) { instance_double(OpenSSL::SSL::SSLSocket) }
    let(:mock_parser) { instance_double(Puma::HttpParser) }
    let(:env) do
      {
        'REQUEST_METHOD' => 'CONNECT',
        'REQUEST_URI' => 'example.com:443',
        'rack.hijack' => mock_hijack
      }
    end

    before do
      allow(mock_hijack).to receive(:call).and_return(mock_client_socket)
      allow(mock_client_socket).to receive(:write)
      allow(mock_client_socket).to receive(:close)
      allow(context_manager).to receive(:setup_ssl_socket).and_return(mock_ssl_socket)
      allow(mock_ssl_socket).to receive(:accept)
      allow(mock_ssl_socket).to receive(:close)
      allow(Puma::HttpParser).to receive(:new).and_return(mock_parser)
      allow(mock_parser).to receive(:finished?).and_return(false, true)
      allow(IO).to receive(:select).and_return([mock_ssl_socket])
      allow(mock_ssl_socket).to receive(:readpartial).and_return("GET / HTTP/1.1\r\n\r\n")
      allow(mock_parser).to receive(:execute) do |request_env, buffer, offset|
        # Simulate parser filling in request_env
        request_env['REQUEST_URI'] = '/'
        request_env['REQUEST_METHOD'] = 'GET'
      end
      allow(app).to receive(:write_response_to)
    end

    context 'when child app returns enumerable body' do
      it 'uses the body as-is' do
        enumerable_body = ['Hello', ' ', 'World']
        allow(child_app).to receive(:call).and_return([200, {}, enumerable_body])
        
        expect(app).to receive(:write_response_to).with(mock_ssl_socket, [200, {}, enumerable_body])
        
        app.send(:handle_connect, env)
      end
    end

    context 'when child app returns non-enumerable body' do
      it 'wraps the body in an array' do
        # Create a non-enumerable object
        non_enumerable_body = Object.new
        def non_enumerable_body.respond_to?(method)
          return false if method == :each
          super
        end
        def non_enumerable_body.to_s
          "Hello World"
        end
        
        allow(child_app).to receive(:call).and_return([200, {}, non_enumerable_body])
        
        expect(app).to receive(:write_response_to).with(mock_ssl_socket, [200, {}, ["Hello World"]])
        
        app.send(:handle_connect, env)
      end
    end
  end

  describe 'client disconnection logging in handle_connect' do
    let(:mock_hijack) { double('hijack') }
    let(:mock_client_socket) { instance_double(Socket) }
    let(:mock_ssl_socket) { instance_double(OpenSSL::SSL::SSLSocket) }
    let(:env) do
      {
        'REQUEST_METHOD' => 'CONNECT',
        'REQUEST_URI' => 'example.com:443',
        'rack.hijack' => mock_hijack
      }
    end

    before do
      allow(mock_hijack).to receive(:call).and_return(mock_client_socket)
      allow(mock_client_socket).to receive(:write)
      allow(mock_client_socket).to receive(:close)
      allow(context_manager).to receive(:setup_ssl_socket).and_return(mock_ssl_socket)
      allow(mock_ssl_socket).to receive(:accept)
      allow(mock_ssl_socket).to receive(:close)
      allow(MitmTestProxy.config).to receive(:log_requests).and_return(true)
    end

    context 'when client disconnects with ECONNRESET' do
      before do
        allow(mock_ssl_socket).to receive(:accept).and_raise(Errno::ECONNRESET, 'Connection reset by peer')
      end

      it 'logs the client disconnection with hostname' do
        expect { app.send(:handle_connect, env) }
          .to output(/MitmTestProxy Client disconnected: example.com/).to_stdout
      end
    end
  end
end