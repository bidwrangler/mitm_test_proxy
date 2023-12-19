# frozen_string_literal: true

require_relative "mitm_test_proxy/version"
require_relative "mitm_test_proxy/proxy_rack_app"
require_relative "mitm_test_proxy/certificate_manager"

require 'puma'
require 'puma/configuration'
require 'puma/events'
require 'webrick'
require 'rack-proxy'
require 'rack'
require 'pp'

module MitmTestProxy
  class MitmTestProxy
    attr_reader :port
    attr_reader :logs

    def initialize
      @stubs = []
      @launcher_thread = nil
      @server_ready = Queue.new
      @server_shutdown = Queue.new
      @logs = StringIO.new
      @log_writer = Puma::LogWriter.new(@logs, @logs)
      @port = nil
      @certificate_path = init_certs

      init_puma
    end

    def init_certs
      certs_dir = Dir.new('certs')
      if !certs_dir.exist?
        certs_dir.mkdir
      end
      certs_dir
    end

    def init_puma
      # Register a custom action when the server starts
      events = Puma::Events.new
      events.register(:state) do |state|
        if state == :running
          @server_ready.push(true)
          @port = @launcher.connected_ports[0]
        end
        @server_shutdown.push(true) if state == :done
      end

      puma_config = Puma::Configuration.new do |user_config, file_config, two|
        user_config.bind "tcp://127.0.0.1:0"
        user_config.app ProxyRackApp.new(@stubs)
        user_config.supported_http_methods Puma::Const::SUPPORTED_HTTP_METHODS + ['CONNECT']
      end

      @launcher = Puma::Launcher.new(
        puma_config,
        events: events,
        log_writer: @log_writer,
      )
    end

    def host
      'localhost'
    end

    def start
      @launcher_thread = Thread.new do
        @launcher.run
      end
      @server_ready.pop
    end

    def shutdown
      @launcher.stop
      if @launcher_thread
        @launcher_thread.join
      end
    end

    def stub(stub_url)
      @stubs << Stub.new(stub_url)
      return @stubs.last
    end
  end

  class Stub
    attr_reader :url, :text

    def initialize(stub_url)
      @url = stub_url
    end

    def and_return(text:)
      @text = text
    end
  end

  class Error < StandardError; end
  # Your code goes here...
end
