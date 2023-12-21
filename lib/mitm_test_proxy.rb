# frozen_string_literal: true

require_relative "mitm_test_proxy/version"
require_relative "mitm_test_proxy/proxy_rack_app"
require_relative "mitm_test_proxy/tls/certificate_helpers"
require_relative "mitm_test_proxy/tls/certificate"
require_relative "mitm_test_proxy/tls/certificate_chain"
require_relative "mitm_test_proxy/tls/authority"

require 'puma'
require 'puma/configuration'
require 'puma/events'
require 'webrick'
require 'rack-proxy'
require 'rack'
require 'pp'

module MitmTestProxy
  class Config
    attr_accessor :certs_path

    def initialize
      @certs_path = File.join(Dir.tmpdir, 'mitm_test_proxy', 'certs')
    end
  end
  def self.config
    @config ||= Config.new
  end

  def self.certificate_authority
    @certificate_authority ||= ::MitmTestProxy::Authority.new
  end

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

      init_puma
    end

    def init_puma
      # Register a custom action when the server starts
      events = Puma::Events.new
      events.register(:state) do |state|
        if state == :running
          @port = @launcher.connected_ports[0]
          @server_ready.push(true)
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
        environment: 'development',
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
