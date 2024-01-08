require 'mitm_test_proxy/tls/context_manager'

RSpec.describe MitmTestProxy::ContextManager do
  let(:context_manager) { described_class.new }

  context('#keys_for') do
    it 'generates a new certificate for each domain' do
      keys = context_manager.keys_for('example.com')
      expect(keys).to have_key(:private_key_file)
      expect(keys).to have_key(:cert_chain_file)
      expect(File).to exist(keys[:private_key_file])
      expect(File).to exist(keys[:cert_chain_file])
    end

    it 'generates a new certificate only once' do
      allow(context_manager).to receive(:create_certificate_for).and_call_original.exactly(1).times
      keys = context_manager.keys_for('example.com')
      keys = context_manager.keys_for('example.com')
    end
  end
end
