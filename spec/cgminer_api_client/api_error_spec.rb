# frozen_string_literal: true

require 'spec_helper'

describe CgminerApiClient::ApiError do
  describe 'CGMINER_CODES' do
    it 'is frozen' do
      expect(described_class::CGMINER_CODES).to be_frozen
    end

    it 'raises FrozenError on element mutation' do
      # be_frozen alone proves the flag is set, not that mutation
      # actually fails — pin the immutability contract callers rely
      # on (e.g., a future PR can't accidentally hand out a mutable
      # reference and have it silently get patched by a consumer).
      expect { described_class::CGMINER_CODES[99] = :foo }
        .to raise_error(FrozenError)
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
      # The constructor calls to_sym so callers can pass either a
      # Symbol or a String for code: without the dispatch-site case
      # statement caring which form was supplied.
      let(:e) { described_class.new('boom', code: 'access_denied') }

      it 'coerces the symbol' do
        expect(e.code).to eq(:access_denied)
      end
    end

    context 'with explicit code: nil and a mapped cgminer_code' do
      # Pins the || semantics: explicit nil falls through to the map
      # lookup. The "both passed" context above only covers truthy
      # explicit codes, so this guards the false-trail of the precedence
      # chain (code || CGMINER_CODES[cgminer_code] || :unknown).
      let(:e) { described_class.new('msg', cgminer_code: 45, code: nil) }

      it 'falls through nil to the map lookup, yielding :access_denied' do
        expect(e.code).to eq(:access_denied)
      end
    end

    context 'with non-Integer cgminer_code (library-boundary input validation)' do
      # The constructor is the library's strict boundary. Without this
      # guard, cgminer_code: "45" silently produces code: :unknown
      # (CGMINER_CODES uses Integer keys), and every dispatch site
      # breaks with no signal. Wire-side callers that want best-effort
      # coercion call Integer(c, exception: false) before constructing.
      it 'raises ArgumentError on a String' do
        expect { described_class.new('msg', cgminer_code: '45') }
          .to raise_error(ArgumentError, /cgminer_code must be Integer or nil/)
      end

      it 'raises ArgumentError on a Float' do
        expect { described_class.new('msg', cgminer_code: 45.0) }
          .to raise_error(ArgumentError, /cgminer_code must be Integer or nil/)
      end

      it 'still accepts an Integer (regression guard for the happy path)' do
        expect { described_class.new('msg', cgminer_code: 45) }
          .not_to raise_error
      end

      it 'still accepts nil (regression guard for the local-guard path)' do
        expect { described_class.new('msg', cgminer_code: nil) }
          .not_to raise_error
      end
    end
  end

  describe '.for_status (factory used by Miner#check_status)' do
    it 'returns AccessDeniedError when the integer maps to :access_denied' do
      e = described_class.for_status(45, 'Access denied')
      expect(e).to be_a(CgminerApiClient::AccessDeniedError)
      expect(e.cgminer_code).to eq(45)
      expect(e.code).to eq(:access_denied)
      expect(e.message).to eq('45: Access denied')
    end

    it 'returns plain ApiError for mapped non-access-denied codes' do
      e = described_class.for_status(14, 'Invalid command')
      expect(e).to be_an_instance_of(described_class)
      expect(e).not_to be_a(CgminerApiClient::AccessDeniedError)
      expect(e.cgminer_code).to eq(14)
      expect(e.code).to eq(:invalid_command)
    end

    it 'returns plain ApiError with :unknown for unmapped codes' do
      e = described_class.for_status(999, 'Strange')
      expect(e).to be_an_instance_of(described_class)
      expect(e.cgminer_code).to eq(999)
      expect(e.code).to eq(:unknown)
    end

    it 'coerces a String Code to Integer (best-effort wire boundary)' do
      # cgminer normally emits Code as integer, but defending against
      # firmware that ever returns "45" as JSON string keeps dispatch
      # working.
      e = described_class.for_status('45', 'Access denied')
      expect(e).to be_a(CgminerApiClient::AccessDeniedError)
      expect(e.cgminer_code).to eq(45)
    end

    it 'falls through to :unknown when the Code is non-numeric' do
      e = described_class.for_status('not-a-number', 'Weird')
      expect(e).to be_an_instance_of(described_class)
      expect(e.cgminer_code).to be_nil
      expect(e.code).to eq(:unknown)
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
