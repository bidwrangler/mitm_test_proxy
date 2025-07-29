#!/usr/bin/env ruby

require_relative 'lib/mitm_test_proxy'
require 'net/http'
require 'openssl'

ENV['MITM_TEST_PROXY_LOG_REQUESTS'] = '1'

puts "Starting simple HTTPS test..."

proxy = MitmTestProxy::MitmTestProxy.new
proxy.stub('https://www.example.com/').and_return(text: "Hello HTTPS")
proxy.start

puts "Proxy started on port #{proxy.port}"

begin
  uri = URI('https://www.example.com/')
  http = Net::HTTP.new(uri.host, uri.port, proxy.host, proxy.port)
  http.use_ssl = true
  http.verify_mode = OpenSSL::SSL::VERIFY_NONE
  
  puts "About to make request..."
  response = http.get(uri.request_uri)
  puts "Response: #{response.code} - #{response.body}"
  
rescue => e
  puts "Error: #{e.class}: #{e.message}"
end

puts "Shutting down proxy..."
proxy.shutdown
puts "=== SIMPLE TEST COMPLETED ==="