# frozen_string_literal: true

require 'net/http'

RSpec.describe MitmTestProxy do
  it "has a version number" do
    expect(MitmTestProxy::VERSION).not_to be nil
  end

  it "can stub a https site" do
    stubbed_text = "I'm not example.com!"
    stub_url = 'https://www.example.com/'
    mitm_test_proxy = MitmTestProxy::MitmTestProxy.new
    mitm_test_proxy.stub(stub_url).and_return(text: stubbed_text)
    proxy_thread = Thread.new { mitm_test_proxy.start }

    proxy_host = 'localhost'
    proxy_port = mitm_test_proxy.port

    # Target URL
    uri = URI(stub_url)

    # Create a Net::HTTP object with proxy settings
    http = Net::HTTP.new(uri.host, uri.port, proxy_host, proxy_port)
    http.use_ssl = uri.scheme == 'https'
    response = http.get(uri.request_uri)

    expect(response.body).to eq(stubbed_text)

    mitm_test_proxy.shutdown
    proxy_thread.join
  end

  it "can stub a http site" do
    stubbed_text = "I'm not example.com!"
    stub_url = 'http://www.example.com/'
    mitm_test_proxy = MitmTestProxy::MitmTestProxy.new
    mitm_test_proxy.stub(stub_url).and_return(text: stubbed_text)
    proxy_thread = Thread.new { mitm_test_proxy.start }

    proxy_host = 'localhost'
    proxy_port = mitm_test_proxy.port

    # Target URL
    uri = URI(stub_url)

    # Create a Net::HTTP object with proxy settings
    http = Net::HTTP.new(uri.host, uri.port, proxy_host, proxy_port)
    http.use_ssl = uri.scheme == 'https'
    response = http.get(uri.request_uri)

    expect(response.body).to eq(stubbed_text)

    mitm_test_proxy.shutdown
    proxy_thread.join
  end
end
