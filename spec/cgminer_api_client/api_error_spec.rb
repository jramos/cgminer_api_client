# frozen_string_literal: true

require 'spec_helper'

describe CgminerApiClient::ApiError do
  describe 'CGMINER_CODES' do
    it 'is frozen' do
      expect(described_class::CGMINER_CODES).to be_frozen
    end

    it 'maps the access-denied integer (45) to :access_denied' do
      expect(described_class::CGMINER_CODES[45]).to eq(:access_denied)
    end

    it 'maps the invalid-command integer (14) to :invalid_command' do
      expect(described_class::CGMINER_CODES[14]).to eq(:invalid_command)
    end
  end

  describe '#initialize' do
    context 'with only a positional message (legacy form)' do
      let(:e) { described_class.new('boom') }

      it 'preserves the message' do
        expect(e.message).to eq('boom')
      end

      it 'leaves cgminer_code nil' do
        expect(e.cgminer_code).to be_nil
      end

      it 'sets code to :unknown' do
        expect(e.code).to eq(:unknown)
      end
    end

    context 'with cgminer_code that maps to a known symbol' do
      let(:e) { described_class.new('45: Access denied', cgminer_code: 45) }

      it 'preserves the cgminer integer' do
        expect(e.cgminer_code).to eq(45)
      end

      it 'derives :access_denied from the integer' do
        expect(e.code).to eq(:access_denied)
      end

      it 'preserves the message' do
        expect(e.message).to eq('45: Access denied')
      end
    end

    context 'with cgminer_code that is not in the map' do
      let(:e) { described_class.new('999: Strange', cgminer_code: 999) }

      it 'preserves the cgminer integer verbatim' do
        expect(e.cgminer_code).to eq(999)
      end

      it 'falls back to :unknown' do
        expect(e.code).to eq(:unknown)
      end
    end

    context 'with cgminer_code nil' do
      let(:e) { described_class.new('boom', cgminer_code: nil) }

      it 'sets code to :unknown' do
        expect(e.code).to eq(:unknown)
      end
    end

    context 'with explicit code: but no cgminer_code' do
      let(:e) { described_class.new('access denied', code: :access_denied) }

      it 'uses the explicit symbol' do
        expect(e.code).to eq(:access_denied)
      end

      it 'leaves cgminer_code nil' do
        expect(e.cgminer_code).to be_nil
      end
    end

    context 'with both cgminer_code and explicit code' do
      let(:e) { described_class.new('foo', cgminer_code: 45, code: :custom) }

      it 'lets the explicit code override the map lookup' do
        expect(e.code).to eq(:custom)
      end

      it 'still preserves the cgminer integer' do
        expect(e.cgminer_code).to eq(45)
      end
    end

    context 'with explicit code as a String' do
      # The to_sym in the constructor coerces strings so callers can
      # pass either form without the dispatch-site case statement
      # caring which.
      let(:e) { described_class.new('boom', code: 'access_denied') }

      it 'coerces the symbol' do
        expect(e.code).to eq(:access_denied)
      end
    end
  end

  describe 'compatibility with raise/rescue' do
    it 'works with raise(class, message) — the legacy two-arg form' do
      expect { raise described_class, 'boom' }
        .to raise_error(described_class) { |e|
          expect(e.message).to eq('boom')
          expect(e.cgminer_code).to be_nil
          expect(e.code).to eq(:unknown)
        }
    end

    it 'works with raise(instance) when constructed with kwargs' do
      expect { raise described_class.new('boom', cgminer_code: 45) }
        .to raise_error(described_class) { |e|
          expect(e.cgminer_code).to eq(45)
          expect(e.code).to eq(:access_denied)
        }
    end

    it 'is rescued by CgminerApiClient::Error (base class)' do
      expect { raise described_class, 'boom' }
        .to raise_error(CgminerApiClient::Error)
    end

    it 'is rescued by StandardError' do
      expect { raise described_class, 'boom' }
        .to raise_error(StandardError)
    end
  end
end
