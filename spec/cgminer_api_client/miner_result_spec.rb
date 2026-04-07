# frozen_string_literal: true

require 'spec_helper'

describe CgminerApiClient::MinerResult do
  let(:miner) { CgminerApiClient::Miner.new('10.0.0.1', 4028) }
  let(:value) { { elapsed: 123 } }
  let(:error) { CgminerApiClient::ConnectionError.new('boom') }

  describe '.success' do
    let(:result) { described_class.success(miner, value) }

    it 'assigns miner and value' do
      expect(result.miner).to eq(miner)
      expect(result.value).to eq(value)
    end

    it 'leaves error nil' do
      expect(result.error).to be_nil
    end

    it 'is ok?' do
      expect(result.ok?).to be(true)
      expect(result.failed?).to be(false)
    end
  end

  describe '.failure' do
    let(:result) { described_class.failure(miner, error) }

    it 'assigns miner and error' do
      expect(result.miner).to eq(miner)
      expect(result.error).to eq(error)
    end

    it 'leaves value nil' do
      expect(result.value).to be_nil
    end

    it 'is failed?' do
      expect(result.failed?).to be(true)
      expect(result.ok?).to be(false)
    end
  end

  describe '#raise!' do
    context 'when ok?' do
      let(:result) { described_class.success(miner, value) }

      it 'returns the value' do
        expect(result.raise!).to eq(value)
      end
    end

    context 'when failed?' do
      let(:result) { described_class.failure(miner, error) }

      it 're-raises the captured error' do
        expect { result.raise! }.to raise_error(CgminerApiClient::ConnectionError, 'boom')
      end
    end
  end

  describe 'equality' do
    it 'considers two successes with identical fields equal' do
      a = described_class.success(miner, { x: 1 })
      b = described_class.success(miner, { x: 1 })
      expect(a).to eq(b)
      expect(a.hash).to eq(b.hash)
    end

    it 'considers a success and a failure unequal' do
      a = described_class.success(miner, value)
      b = described_class.failure(miner, error)
      expect(a).not_to eq(b)
    end
  end

  describe 'pattern matching via deconstruct_keys' do
    it 'matches an ok? branch' do
      result = described_class.success(miner, value)
      matched =
        case result
        in { value: { elapsed: } } then elapsed
        end
      expect(matched).to eq(123)
    end

    it 'matches a failed? branch' do
      result = described_class.failure(miner, error)
      matched =
        case result
        in { error: } then error.message
        end
      expect(matched).to eq('boom')
    end
  end

  describe 'immutability' do
    it 'is frozen' do
      result = described_class.success(miner, value)
      expect { result.instance_variable_set(:@value, 'mutated') }
        .to raise_error(FrozenError)
    end
  end
end
