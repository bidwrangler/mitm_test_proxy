# frozen_string_literal: true

RSpec.describe MitmTestProxy::CertificateManager do
  it "can create a certificate authority" do
    certificate_path = Pathname.new('certs')
    certificate_manager = MitmTestProxy::CertificateManager.new(certificate_path)
    certificate_manager.create_certificate_authority
    expect(certificate_path.join('ca.crt')).to exist
  end
end
