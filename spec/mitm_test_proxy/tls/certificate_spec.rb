# frozen_string_literal: true

RSpec.describe MitmTestProxy::Certificate do
  let(:cert1) { MitmTestProxy::Certificate.new('localhost') }
  let(:cert2) { MitmTestProxy::Certificate.new('localhost.localdomain') }

  context('#domain') do
    it 'holds the domain' do
      expect(MitmTestProxy::Certificate.new('test.tld').domain).to be_eql('test.tld')
    end
  end

  context('#key') do
    it 'generates a new key each time' do
      expect(cert1.key).not_to be(cert2.key)
    end

    it 'generates 2048 bit keys' do
      expect(cert1.key.n.num_bytes * 8).to be(2048)
    end
  end

  context('#cert') do
    it 'generates a new certificate each time' do
      expect(cert1.cert).not_to be(cert2.cert)
    end

    it 'generates unique serials' do
      expect(cert1.cert.serial).not_to be(cert2.cert.serial)
    end

    it 'configures a start date some days ago' do
      expect(cert1.cert.not_before).to \
        be_between((Date.today - 3).to_time, Date.today.to_time)
    end

    it 'configures an end date in some days' do
      expect(cert1.cert.not_after).to \
        be_between(Date.today.to_time, (Date.today + 3).to_time)
    end

    it 'configures the correct subject' do
      expect(cert1.cert.subject.to_s).to be_eql('/CN=localhost')
    end

    it 'configures the subject alternative names' do
      expect(cert1.cert.extensions.first.to_s).to \
        be_eql('subjectAltName = DNS:localhost')
    end

    it 'configures SSLv3' do
      # Zero-index version numbers. Yay.
      expect(cert1.cert.version).to be(2)
    end
  end

  context('#key_file') do
    it 'pass back the path' do
      expect(cert1.key_file).to match(/request-localhost.key$/)
    end

    it 'creates a temporary file' do
      expect(File.exist?(cert1.key_file)).to be(true)
    end

    it 'creates a PEM formatted certificate' do
      expect(File.read(cert1.key_file)).to match(/^[A-Za-z0-9\-\+\/\=]+$/)
    end

    it 'writes out a private key' do
      key = OpenSSL::PKey::RSA.new(File.read(cert1.key_file))
      expect(key.private?).to be(true)
    end
  end

  context('#cert_file') do
    it 'pass back the path' do
      expect(cert1.cert_file).to match(/request-localhost.crt$/)
    end

    it 'creates a temporary file' do
      expect(File.exist?(cert1.cert_file)).to be(true)
    end

    it 'creates a PEM formatted certificate' do
      expect(File.read(cert1.cert_file)).to match(/^[A-Za-z0-9\-\+\/\=]+$/)
    end
  end
end
