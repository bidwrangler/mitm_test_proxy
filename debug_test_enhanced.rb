#!/usr/bin/env ruby

require_relative 'lib/mitm_test_proxy'
require 'net/http'
require 'openssl'
require 'timeout'

puts "=== Enhanced Debug Test for HTTPS Hanging Issue ==="

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

# Test HTTP first to verify basic functionality
puts "\n=== Testing HTTP (should work) ==="
proxy.stub('http://www.example.com/').and_return(text: "Hello HTTP")

begin
  puts "[DEBUG] Making HTTP request..."
  uri = URI('http://www.example.com/')
  http = Net::HTTP.new(uri.host, uri.port, proxy.host, proxy.port)
  
  puts "[DEBUG] HTTP request configured, sending..."
  response = http.get(uri.request_uri)
  puts "[DEBUG] ✓ HTTP Response received: #{response.code} - #{response.body}"
rescue => e
  puts "[DEBUG] ✗ HTTP Error: #{e.class}: #{e.message}"
  puts "[DEBUG] HTTP Error backtrace: #{e.backtrace.first(5).join('\n')}"
end

# Now test HTTPS with detailed debugging
puts "\n=== Testing HTTPS (problematic) ==="

begin
  puts "[DEBUG] Creating HTTPS URI..."
  uri = URI('https://www.example.com/')
  puts "[DEBUG] ✓ URI created: #{uri}"
  
  puts "[DEBUG] Creating Net::HTTP with proxy settings..."
  http = Net::HTTP.new(uri.host, uri.port, proxy.host, proxy.port)
  puts "[DEBUG] ✓ Net::HTTP created"
  
  puts "[DEBUG] Configuring SSL settings..."
  http.use_ssl = true
  http.verify_mode = OpenSSL::SSL::VERIFY_NONE
  http.read_timeout = 10
  http.open_timeout = 10
  puts "[DEBUG] ✓ SSL configured"
  
  puts "[DEBUG] About to make HTTPS request..."
  puts "[DEBUG] This is where it typically hangs..."
  
  # Use timeout to prevent infinite hang
  response = Timeout::timeout(15) do
    puts "[DEBUG] Inside timeout block, calling http.get..."
    result = http.get(uri.request_uri)
    puts "[DEBUG] http.get returned successfully!"
    result
  end
  
  puts "[DEBUG] ✓ HTTPS Response received: #{response.code} - #{response.body}"
  
rescue Timeout::Error => e
  puts "[DEBUG] ✗ HTTPS TIMEOUT after 15 seconds - this confirms hanging issue"
  puts "[DEBUG] Timeout error: #{e.message}"
  
  # Try to get proxy logs for debugging
  begin
    puts "\n[DEBUG] Proxy logs during hang:"
    puts proxy.logs.string
  rescue => log_error
    puts "[DEBUG] Could not retrieve proxy logs: #{log_error.message}"
  end
  
rescue => e
  puts "[DEBUG] ✗ HTTPS Error: #{e.class}: #{e.message}"
  puts "[DEBUG] HTTPS Error backtrace:"
  puts e.backtrace.first(10).join("\n")
  
  # Try to get proxy logs
  begin
    puts "\n[DEBUG] Proxy logs during error:"
    puts proxy.logs.string
  rescue => log_error
    puts "[DEBUG] Could not retrieve proxy logs: #{log_error.message}"
  end
end

puts "\n[DEBUG] Shutting down proxy..."
proxy.shutdown
puts "[DEBUG] ✓ Proxy shutdown complete"

puts "\n=== Debug Analysis ==="
puts "1. If HTTP works but HTTPS times out, the issue is in HTTPS-specific code"
puts "2. Check HttpConnectApp.handle_connect method for blocking operations"
puts "3. Look for infinite loops in parser or SSL socket operations"
puts "4. Verify SSL certificate generation is not blocking"