#!/usr/bin/env ruby

require_relative 'lib/mitm_test_proxy'
require 'net/http'
require 'openssl'
require 'timeout'

# Enable logging to see detailed debug output
ENV['MITM_TEST_PROXY_LOG_REQUESTS'] = '1'

puts "=== Debug Test with Detailed Logging ==="

# Create proxy
puts "[DEBUG] Creating proxy..."
proxy = MitmTestProxy::MitmTestProxy.new
puts "[DEBUG] ✓ Proxy created"

# Add HTTPS stub
puts "[DEBUG] Adding HTTPS stub..."
proxy.stub('https://www.example.com/').and_return(text: "Hello HTTPS")
puts "[DEBUG] ✓ HTTPS stub added"

# Start proxy
puts "[DEBUG] Starting proxy..."
proxy.start
puts "[DEBUG] ✓ Proxy started on port #{proxy.port}"

# Test HTTPS with detailed debugging
puts "\n=== Testing HTTPS ==="

begin
  puts "[DEBUG] Creating HTTPS URI..."
  uri = URI('https://www.example.com/')
  
  puts "[DEBUG] Creating Net::HTTP with proxy settings..."
  http = Net::HTTP.new(uri.host, uri.port, proxy.host, proxy.port)
  http.use_ssl = true
  http.verify_mode = OpenSSL::SSL::VERIFY_NONE
  http.read_timeout = 5
  http.open_timeout = 5
  
  puts "[DEBUG] About to make HTTPS request..."
  
  # Use shorter timeout to see debug output before hang
  response = Timeout::timeout(8) do
    http.get(uri.request_uri)
  end
  
  puts "[DEBUG] ✓ HTTPS Response received: #{response.code} - #{response.body}"
  
rescue Timeout::Error => e
  puts "[DEBUG] ✗ HTTPS TIMEOUT - checking where it hung..."
  
rescue => e
  puts "[DEBUG] ✗ HTTPS Error: #{e.class}: #{e.message}"
  puts e.backtrace.first(5).join("\n")
end

puts "\n[DEBUG] Shutting down proxy..."
proxy.shutdown
puts "[DEBUG] ✓ Proxy shutdown complete"