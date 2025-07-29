#!/usr/bin/env ruby

require_relative 'lib/mitm_test_proxy'
require 'net/http'
require 'openssl'

puts "=== Testing HTTP first ==="

# Create proxy
proxy = MitmTestProxy::MitmTestProxy.new
puts "✓ Proxy created"

# Add HTTP stub
proxy.stub('http://www.example.com/').and_return(text: "Hello HTTP")
puts "✓ HTTP stub added"

# Start proxy
proxy.start
puts "✓ Proxy started on port #{proxy.port}"

# Test HTTP first
puts "Making HTTP request..."
begin
  uri = URI('http://www.example.com/')
  http = Net::HTTP.new(uri.host, uri.port, proxy.host, proxy.port)
  response = http.get(uri.request_uri)
  puts "✓ HTTP Response: #{response.code} - #{response.body}"
rescue => e
  puts "✗ HTTP Error: #{e.class}: #{e.message}"
end

# Now test HTTPS
puts "Making HTTPS request..."
proxy.stub('https://www.example.com/').and_return(text: "Hello HTTPS")

begin
  uri = URI('https://www.example.com/')
  http = Net::HTTP.new(uri.host, uri.port, proxy.host, proxy.port)
  http.use_ssl = true
  http.verify_mode = OpenSSL::SSL::VERIFY_NONE
  response = http.get(uri.request_uri)
  puts "✓ HTTPS Response: #{response.code} - #{response.body}"
rescue => e
  puts "✗ HTTPS Error: #{e.class}: #{e.message}"
  puts e.backtrace.first(3)
end

proxy.shutdown
puts "✓ Proxy shutdown"