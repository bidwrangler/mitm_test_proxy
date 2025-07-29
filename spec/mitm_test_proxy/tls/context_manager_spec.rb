require 'mitm_test_proxy/tls/context_manager'

RSpec.describe MitmTestProxy::ContextManager do
  let(:context_manager) { described_class.new }
  
  after do
    # Clean up certificates after each test to prevent file accumulation
    context_manager.cleanup_certificates
  end

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
  
  context('#cleanup_certificates') do
    it 'removes certificate files and clears cache' do
      keys = context_manager.keys_for('example.com')
      private_key_file = keys[:private_key_file]
      cert_chain_file = keys[:cert_chain_file]
      
      expect(File).to exist(private_key_file)
      expect(File).to exist(cert_chain_file)
      
      context_manager.cleanup_certificates
      
      expect(File).not_to exist(private_key_file)
      expect(File).not_to exist(cert_chain_file)
      
      # Should generate new certificates after cleanup (files should exist again)
      new_keys = context_manager.keys_for('example.com')
      expect(File).to exist(new_keys[:private_key_file])
      expect(File).to exist(new_keys[:cert_chain_file])
      
      # Cache should have been cleared, so create_certificate_for should be called again
      expect(context_manager).to receive(:create_certificate_for).once.and_call_original
      context_manager.keys_for('test.com')
    end
    
    it 'handles missing files gracefully' do
      keys = context_manager.keys_for('example.com')
      File.unlink(keys[:private_key_file]) if File.exist?(keys[:private_key_file])
      
      expect { context_manager.cleanup_certificates }.not_to raise_error
    end
  end
end
