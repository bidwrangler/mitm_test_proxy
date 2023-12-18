# frozen_string_literal: true

require_relative "mitm_test_proxy/version"

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
    end

    def port
      return 8080
    end

    def stub(stub_url)
      @stubs << Stub.new(stub_url)
      return @stubs.last
    end
  end


  class Error < StandardError; end
  # Your code goes here...
end
