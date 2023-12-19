# frozen_string_literal: true

require_relative "mitm_test_proxy/version"
require 'webrick'

module MitmTestProxy

  class Stub
    def initialize(stub_url)
      @url = stub_url
    end

    def and_return(text:)
      @text = text
    end
  end

  class MitmTestProxy
    def initialize
      @stubs = []
      @server_thread = nil
      @server_queue = Queue.new
      @log = WEBrick::Log.new(nil, WEBrick::Log::DEBUG)
      @server = WEBrick::HTTPServer.new(Port: port, StartCallback: Proc.new do
        @server_queue << true
      end, Logger: @log, AccessLog: [])
    end

    def host
      'localhost'
    end

    def port
      return 8080
    end

    def start
      puts "start was called"
      @server_thread = Thread.new do
        @server.start
      end
      @server_queue.pop
      puts "end of start"
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
