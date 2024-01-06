# frozen_string_literal: true

require 'net/http'
require 'openssl'
require 'open3'

RSpec.describe MitmTestProxy do
  it "has a version number" do
    expect(MitmTestProxy::VERSION).not_to be nil
  end

  it "can stub a http site" do
    stubbed_text = "I'm not example.com!"
    stub_url = 'http://www.example.com/'
    mitm_test_proxy = MitmTestProxy::MitmTestProxy.new
    mitm_test_proxy.stub(stub_url).and_return(text: stubbed_text)
    mitm_test_proxy.start

    # Target URL
    uri = URI(stub_url)

    # Create a Net::HTTP object with proxy settings
    expect(mitm_test_proxy.port).to be > 0

    http = Net::HTTP.new(uri.host, uri.port, mitm_test_proxy.host, mitm_test_proxy.port)
    response = http.get(uri.request_uri)

    expect(response.body).to eq(stubbed_text)

    mitm_test_proxy.shutdown
  end

  it "can stub a https site" do
    stubbed_text = "I'm not https example.com!"
    stub_url = 'https://www.example.com/'
    mitm_test_proxy = MitmTestProxy::MitmTestProxy.new
    mitm_test_proxy.stub(stub_url).and_return(text: stubbed_text)
    mitm_test_proxy.start

    # Target URL
    uri = URI(stub_url)

    # Create a Net::HTTP object with proxy settings
    http = Net::HTTP.new(uri.host, uri.port, mitm_test_proxy.host, mitm_test_proxy.port)
    http.use_ssl = uri.scheme == 'https'
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE
    begin
      response = http.get(uri.request_uri)
    rescue => e
      puts "logs:"
      puts mitm_test_proxy.logs.string
      raise
    end

    expect(response.code).to eq("200")
    expect(response.body).to eq(stubbed_text)

    mitm_test_proxy.shutdown
  end

  # just like puffing-billy
  it "can stub with a regex and proc" do
    stub_url = 'https://www.example.com/hello.txt'
    stubbed_text = "hello world"

    mitm_test_proxy = MitmTestProxy::MitmTestProxy.new
    mitm_test_proxy.stub(/hello.txt/).and_return(Proc.new { |env|
      headers = {
        "Content-type" => "text/plain",
        "Access-Control-Allow-Origin" => "*",
      }
      [200, headers, [stubbed_text]]
    })
    mitm_test_proxy.start

    # Target URL
    uri = URI(stub_url)

    # Create a Net::HTTP object with proxy settings
    http = Net::HTTP.new(uri.host, uri.port, mitm_test_proxy.host, mitm_test_proxy.port)
    response = http.get(uri.request_uri)

    expect(response.code).to eq("200")

    expect(response.body).to eq(stubbed_text)
    expect(response.header["Content-type"]).to eq("text/plain")
    expect(response.header["access-control-allow-origin"]).to eq("*")
  end

  it "will recover from an error while proxying and send the error to the ssl socket" do
    stub_url = 'https://www.example.com/hello.txt'
    stubbed_text = "hello world"

    mitm_test_proxy = MitmTestProxy::MitmTestProxy.new
    mitm_test_proxy.start
    allow_any_instance_of(Rack::Proxy).to receive(:call).and_raise("error while proxying")

    # Target URL
    uri = URI(stub_url)

    # Create a Net::HTTP object with proxy settings
    http = Net::HTTP.new(uri.host, uri.port, mitm_test_proxy.host, mitm_test_proxy.port)
    response = http.get(uri.request_uri)

    expect(response.code).to eq("500")

    expect(response.body).to start_with("Puma caught this error: error while proxying (RuntimeError)")
  end


  it "can stub and stream a file" do
    stub_url = 'https://www.example.com/thisfile.rb'

    mitm_test_proxy = MitmTestProxy::MitmTestProxy.new
    mitm_test_proxy.stub(/thisfile.rb/).and_return(Proc.new { |env|
      headers = {
        "Content-type" => "text/plain",
      }
      [200, headers, MitmTestProxy::FileStreamer.new(__FILE__)]
    })
    mitm_test_proxy.start

    # Target URL
    uri = URI(stub_url)

    # Create a Net::HTTP object with proxy settings
    verify_callback =  lambda do |verify_result, cert|
      verify_result = OpenSSL::SSL::VERIFY_PEER
      if cert.issuer.to_s == cert.subject.to_s
          verify_result = OpenSSL::SSL::VERIFY_NONE
      end
      verify_result
    end

    http_options = {
      verify_mode: OpenSSL::SSL::VERIFY_NONE,
      verify_callback: verify_callback,
      use_ssl: true,
    }
    Net::HTTP.start(uri.host, uri.port, mitm_test_proxy.host, mitm_test_proxy.port, http_options) do |http|
      request1 = Net::HTTP::Get.new(uri)
      response1 = http.request(request1)
      expect(response1.code).to eq("200")
      expect(response1.header["Content-type"]).to eq("text/plain")
      expect(response1.body.length).to eq(File.size(__FILE__))

      request2 = Net::HTTP::Get.new(uri)
      response2 = http.request(request2)
      expect(response2.code).to eq("200")
      expect(response2.header["Content-type"]).to eq("text/plain")
      expect(response2.body.length).to eq(File.size(__FILE__))
    end
    mitm_test_proxy.shutdown
  end

  it "can be used for multiple https requests to the same host in the same connection" do
    stubbed_text = "I'm not https example.com!"
    stub_url = 'https://www.example.com/'
    mitm_test_proxy = MitmTestProxy::MitmTestProxy.new
    mitm_test_proxy.stub(stub_url).and_return(text: stubbed_text)
    mitm_test_proxy.start

    # Target URL
    uri = URI(stub_url)

    verify_callback =  lambda do |verify_result, cert|
      verify_result = OpenSSL::SSL::VERIFY_PEER
      if cert.issuer.to_s == cert.subject.to_s
          verify_result = OpenSSL::SSL::VERIFY_NONE
      end
      verify_result
    end

    http_options = {
      verify_mode: OpenSSL::SSL::VERIFY_NONE,
      verify_callback: verify_callback,
      use_ssl: true,
    }
    Net::HTTP.start(uri.host, uri.port, mitm_test_proxy.host, mitm_test_proxy.port, http_options) do |http|
      request1 = Net::HTTP::Get.new(uri)
      response1 = http.request(request1)
      expect(response1.code).to eq("200")
      expect(response1.body).to eq(stubbed_text)

      request2 = Net::HTTP::Get.new(uri)
      response2 = http.request(request2)
      expect(response2.code).to eq("200")
      expect(response2.body).to eq(stubbed_text)
    end

    mitm_test_proxy.shutdown
  end

  it "can be used with curl https" do
    mitm_test_proxy = MitmTestProxy::MitmTestProxy.new
    mitm_test_proxy.start

    command = "curl --insecure --proxy http://#{mitm_test_proxy.host}:#{mitm_test_proxy.port} https://httpbin.org/get"

    stdout_str, stderr_str, status = Open3.capture3(command)
    if status.exitstatus != 0
      puts "Standard Output: #{stdout_str}"
      puts "Standard Error: #{stderr_str}"
      puts "Exit Status: #{status.exitstatus}"
    end

    expect(status.exitstatus).to eq(0)
  end
end
