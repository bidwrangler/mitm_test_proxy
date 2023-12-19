# frozen_string_literal: true

require_relative "lib/mitm_test_proxy/version"

Gem::Specification.new do |spec|
  spec.name = "mitm_test_proxy"
  spec.version = MitmTestProxy::VERSION
  spec.authors = ["Myers Carpenter"]
  spec.email = ["myers@maski.org"]

  spec.summary = "A Man-In-The-Middle Web Proxy for testing"
  spec.description = "A Man-In-The-Middle Web Proxy for testing"
  spec.homepage = "https://github.com/bidwrangler/mitm_test_proxy"
  spec.required_ruby_version = ">= 2.6.0"

  #spec.metadata["allowed_push_host"] = "TODO: Set to your gem server 'https://example.com'"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/bidwrangler/mitm_test_proxy"

  # FIXME
  spec.metadata["changelog_uri"] = "https://github.com/bidwrangler/mitm_test_proxy"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject do |f|
      (File.expand_path(f) == __FILE__) ||
        f.start_with?(*%w[bin/ test/ spec/ features/ .git .circleci appveyor Gemfile])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "webrick", "~> 1.8"
  spec.add_dependency "rack-proxy", "~> 0.7.7"
  spec.add_dependency "rackup", "~> 2.1.0"


  spec.add_development_dependency "rspec-core"

end
