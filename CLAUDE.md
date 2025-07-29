# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Development Commands

### Testing
- `bundle exec rspec` - Run all tests
- `bundle exec rspec spec/path_to_spec.rb` - Run a specific test file
- `bundle exec rspec spec/path_to_spec.rb:line_number` - Run a specific test at line number

### Code Quality
- `bundle exec rubocop` - Lint Ruby code
- `bundle exec rake` - Run default task (specs + rubocop)

### Gem Development
- `bundle exec rake build` - Build the gem
- `bundle exec rake install` - Install the gem locally
- `bundle exec rake release` - Release the gem (requires appropriate permissions)

## Architecture Overview

This is a Ruby gem that provides a Man-In-The-Middle (MITM) proxy server for testing purposes. It's designed to intercept HTTP/HTTPS traffic during tests, allowing you to stub responses and assert on requests made by your application.

### Technology Stack
- **Ruby**: >= 2.6.0
- **Web Server**: Puma 6.4.x
- **Proxy**: rack-proxy 0.7.7
- **Testing**: RSpec
- **TLS**: Custom certificate authority and dynamic certificate generation

### Core Components

#### Main Proxy Server (`lib/mitm_test_proxy.rb`)
- `MitmTestProxy::MitmTestProxy` - Main proxy server class
- Uses Puma as the underlying web server
- Supports HTTP CONNECT method for HTTPS tunneling
- Provides stubbing mechanism for intercepting requests
- Tracks domains seen during proxy usage

#### TLS Certificate Management (`lib/mitm_test_proxy/tls/`)
- `Authority` - Certificate authority for generating dynamic certificates
- `Certificate` - Individual certificate management
- `CertificateChain` - Certificate chain handling
- `ContextManager` - TLS context management for different domains
- `CertificateHelpers` - Utility functions for certificate operations

#### Rack Applications (`lib/mitm_test_proxy/`)
- `HttpConnectApp` - Handles HTTP CONNECT requests for HTTPS tunneling
- `StubApp` - Manages request stubbing and response generation
- `DomainsSeenApp` - Tracks which domains are accessed through the proxy
- `FileStreamer` - Handles file streaming operations

### Key Features

#### Request Stubbing
The proxy allows stubbing responses for specific URLs:
```ruby
proxy.stub('http://example.com/').and_return(text: "Custom response")
proxy.stub(/.*\.api\.com/).and_return(proc { |env| [200, {}, ["JSON response"]] })
```

#### HTTPS Support
- Dynamically generates TLS certificates for intercepted domains
- Uses a self-signed certificate authority
- Requires browser/client configuration to accept self-signed certificates

#### Domain Tracking
- Records all domains accessed through the proxy
- Useful for understanding external dependencies in tests

### Configuration

#### Environment Variables
- `MITM_TEST_PROXY_LOG_REQUESTS` - Enable request logging when set

#### Certificate Storage
- Certificates stored in `Dir.tmpdir/mitm_test_proxy/certs` by default
- Configurable via `MitmTestProxy.config.certs_path`

### Testing Strategy
- Uses RSpec for testing
- Tests cover TLS certificate generation, proxy functionality, and stubbing
- Test files located in `spec/` directory
- Includes integration tests for the full proxy stack

### Development Workflow

#### Gem Structure
- Standard Ruby gem structure with `lib/`, `spec/`, and configuration files
- Main entry point is `lib/mitm_test_proxy.rb`
- Version defined in `lib/mitm_test_proxy/version.rb`

#### Dependencies
- Production: puma, rack-proxy, rack
- Development: rspec, pry for debugging, rubocop for linting

#### Code Organization
- Modular design with separate concerns (TLS, HTTP handling, stubbing)
- Each Rack app has a single responsibility
- TLS functionality isolated in its own namespace

### Usage Pattern
Typical usage in tests:
1. Create proxy instance
2. Configure stubs for expected external requests
3. Start proxy in background thread
4. Configure test client to use proxy
5. Run tests
6. Shutdown proxy
7. Assert on captured requests/domains