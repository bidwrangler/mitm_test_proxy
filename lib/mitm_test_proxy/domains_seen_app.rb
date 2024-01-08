# frozen_string_literal: true

module MitmTestProxy
  # keep track of all the domains we've seen, while forwarding requests to the `child_app`
  class DomainsSeenApp
    def initialize(child_app, domains_seen)
      @child_app = child_app
      @domains_seen = domains_seen
    end

    def call(env)
      URI.parse(env.fetch('REQUEST_URI')).tap do |uri|
        @domains_seen[uri.host] += 1
      end
      @child_app.call(env)
    end
  end
end
