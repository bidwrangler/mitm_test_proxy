# frozen_string_literal: true

require_relative "mitm_test_proxy/version"
require 'webrick'
require 'rack-proxy'
require 'rackup/handler/webrick'
require 'rack'
require 'pp'

module MitmTestProxy

  class Stub
    attr_reader :url, :text

    def initialize(stub_url)
      @url = stub_url
    end

    def and_return(text:)
      @text = text
    end
  end

  class ProxyRackApp < Rack::Proxy
    def initialize(stubs)
      @stubs = stubs
    end

    def call(env)
      @stubs.each do |stub|
        if stub.url == env["REQUEST_URI"]
          headers = {}
          headers["content-type"] = "text/plain"
          body = stub.text

          return [200, headers, [body]]
        end
      end

      super(env)
    end
  end

  class MitmTestProxy
    def initialize
      @stubs = []
      @server_thread = nil
      @server_queue = Queue.new
      @log = WEBrick::Log.new(nil, WEBrick::Log::ERROR)
      start_callback = Proc.new do
        @server_queue << true
      end
      @server = WEBrick::HTTPServer.new(
        Port: 0,
        StartCallback: start_callback,
        Logger: @log,
        AccessLog: []
      )
      @server.mount '/', Rack::Handler::WEBrick, ProxyRackApp.new(@stubs)
    end

    def host
      'localhost'
    end

    def port
      return @server.config[:Port]
    end

    def start
      @server_thread = Thread.new do
        @server.start
      end
      @server_queue.pop
    end

    def shutdown
      @server.shutdown
      if @server_thread
        @server_thread.join
      end
    end

    def stub(stub_url)
      @stubs << Stub.new(stub_url)
      return @stubs.last
    end
  end


  class Error < StandardError; end
  # Your code goes here...
end
