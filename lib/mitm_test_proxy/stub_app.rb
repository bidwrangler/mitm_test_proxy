# frozen_string_literal: true

module MitmTestProxy
  # Using a list of MitmTestProxy::Stub objects, return the stubbed response.  If no stub found for the url,
  # forward requests to the `child_app`.
  class StubApp
    def initialize(child_app, stubs)
      @child_app = child_app
      @stubs = stubs
    end

    def log(msg)
      return unless ::MitmTestProxy.config.log_requests
      puts msg
    end

    def call(env)
      @stubs.each do |stub|
        if stub.match?(env.fetch("REQUEST_URI"))
          log("MitmTestProxy Stubbing request for #{env.fetch('REQUEST_URI').inspect}, using stub with url #{stub.url.inspect}")
          begin
            return stub.call(env)
          rescue => error
            log("MitmTestProxy Error in stub: #{error.inspect}, #{error.backtrace.join("\n")}")
            raise
          end
        end
      end

      @child_app.call(env)
    end
  end
end
