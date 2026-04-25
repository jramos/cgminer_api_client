# frozen_string_literal: true

require 'spec_helper'

describe CgminerApiClient::AccessDeniedError do
  describe 'class hierarchy' do
    it 'inherits from ApiError so existing `rescue ApiError` clauses still catch it' do
      expect(described_class.ancestors).to include(CgminerApiClient::ApiError)
    end

    it 'inherits from Error so `rescue CgminerApiClient::Error` still catches it' do
      expect(described_class.ancestors).to include(CgminerApiClient::Error)
    end

    it 'is a StandardError descendant' do
      expect(described_class.ancestors).to include(StandardError)
    end
  end

  describe '#initialize' do
    context 'with default args (the access_denied? local-guard form)' do
      let(:e) { described_class.new('access denied') }

      it 'preserves the message' do
        expect(e.message).to eq('access denied')
      end

      it 'pins code to :access_denied regardless of constructor input' do
        expect(e.code).to eq(:access_denied)
      end

      it 'leaves cgminer_code nil when not supplied' do
        expect(e.cgminer_code).to be_nil
      end
    end

    context 'with cgminer_code (the wire-side Code 45 form)' do
      let(:e) { described_class.new('45: Access denied', cgminer_code: 45) }

      it 'preserves the cgminer integer' do
        expect(e.cgminer_code).to eq(45)
      end

      it 'still pins code to :access_denied' do
        expect(e.code).to eq(:access_denied)
      end
    end
  end

  describe 'rescue dispatch' do
    it 'is rescued by `rescue AccessDeniedError`' do
      expect { raise described_class, 'denied' }
        .to raise_error(described_class)
    end

    it 'is rescued by `rescue ApiError` (subclass dispatch)' do
      expect { raise described_class, 'denied' }
        .to raise_error(CgminerApiClient::ApiError)
    end

    it 'is rescued by `rescue CgminerApiClient::Error` (base dispatch)' do
      expect { raise described_class, 'denied' }
        .to raise_error(CgminerApiClient::Error)
    end
  end
end
