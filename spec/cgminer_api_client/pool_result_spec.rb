# frozen_string_literal: true

require 'spec_helper'

describe CgminerApiClient::PoolResult do
  let(:miner_a) { CgminerApiClient::Miner.new('10.0.0.1', 4028) }
  let(:miner_b) { CgminerApiClient::Miner.new('10.0.0.2', 4028) }
  let(:miner_c) { CgminerApiClient::Miner.new('10.0.0.3', 4028) }
  let(:success_a) { CgminerApiClient::MinerResult.success(miner_a, { elapsed: 1 }) }
  let(:success_b) { CgminerApiClient::MinerResult.success(miner_b, { elapsed: 2 }) }
  let(:failure_c) { CgminerApiClient::MinerResult.failure(miner_c, CgminerApiClient::ConnectionError.new('boom')) }
  let(:result)    { described_class.new([success_a, success_b, failure_c]) }

  describe 'Enumerable' do
    it 'iterates MinerResult instances in order' do
      yielded = result.map(&:miner)
      expect(yielded).to eq([miner_a, miner_b, miner_c])
    end

    it 'supports #first, #count, #find, #map via Enumerable' do
      expect(result.first).to eq(success_a)
      expect(result.count).to eq(3)
      expect(result.find(&:failed?)).to eq(failure_c)
    end
  end

  describe '#size and #empty?' do
    it 'reports size correctly' do
      expect(result.size).to eq(3)
      expect(result.empty?).to be(false)
    end

    it 'reports empty correctly for an empty PoolResult' do
      empty = described_class.new([])
      expect(empty.size).to eq(0)
      expect(empty.empty?).to be(true)
    end
  end

  describe '#to_a' do
    it 'returns an Array of MinerResult instances' do
      expect(result.to_a).to eq([success_a, success_b, failure_c])
    end

    it 'returns a copy, not the underlying array' do
      result.to_a.push(:mutated)
      expect(result.size).to eq(3)
    end
  end

  describe '#values' do
    it 'returns only the values from successful results' do
      expect(result.values).to eq([{ elapsed: 1 }, { elapsed: 2 }])
    end
  end

  describe '#errors' do
    it 'returns only the errors from failed results' do
      expect(result.errors.size).to eq(1)
      expect(result.errors.first).to be_a(CgminerApiClient::ConnectionError)
    end
  end

  describe '#successful and #failed' do
    it 'returns only ok? MinerResults from #successful' do
      expect(result.successful).to eq([success_a, success_b])
    end

    it 'returns only !ok? MinerResults from #failed' do
      expect(result.failed).to eq([failure_c])
    end
  end

  describe '#all_successful?' do
    it 'is false when any result failed' do
      expect(result.all_successful?).to be(false)
    end

    it 'is true when every result succeeded' do
      expect(described_class.new([success_a, success_b]).all_successful?).to be(true)
    end

    it 'is true for an empty PoolResult' do
      expect(described_class.new([]).all_successful?).to be(true)
    end
  end

  describe '#any_succeeded?' do
    it 'is true when any result succeeded' do
      expect(result.any_succeeded?).to be(true)
    end

    it 'is false when every result failed' do
      only_failed = described_class.new([failure_c])
      expect(only_failed.any_succeeded?).to be(false)
    end
  end

  describe '#any_failed?' do
    it 'is true when any result failed' do
      expect(result.any_failed?).to be(true)
    end

    it 'is false when every result succeeded' do
      expect(described_class.new([success_a, success_b]).any_failed?).to be(false)
    end
  end

  describe '#[]' do
    it 'looks up by integer index' do
      expect(result[0]).to eq(success_a)
      expect(result[2]).to eq(failure_c)
    end

    it 'looks up by "host:port" string' do
      expect(result['10.0.0.2:4028']).to eq(success_b)
    end

    it 'returns nil for an unknown host:port string' do
      expect(result['no.such.host:4028']).to be_nil
    end

    it 'looks up by Miner instance' do
      expect(result[miner_a]).to eq(success_a)
      expect(result[miner_c]).to eq(failure_c)
    end
  end

  describe 'equality' do
    it 'considers two PoolResults with identical results equal' do
      a = described_class.new([success_a, success_b])
      b = described_class.new([success_a, success_b])
      expect(a).to eq(b)
      expect(a.hash).to eq(b.hash)
    end

    it 'considers PoolResults with different results unequal' do
      a = described_class.new([success_a])
      b = described_class.new([success_b])
      expect(a).not_to eq(b)
    end
  end

  describe 'immutability' do
    it 'freezes the underlying results array' do
      expect(result.results).to be_frozen
    end
  end
end
