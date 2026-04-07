# frozen_string_literal: true

require 'spec_helper'

describe CgminerApiClient do
  subject { CgminerApiClient }

  before do
    subject.default_timeout = 5
    subject.default_port = 4028
  end

  it 'has a version constant with major.minor.patch' do
    expect(subject::VERSION).not_to be_empty
    expect(subject::VERSION.split('.').length).to eq(3)
  end

  context 'module attributes' do
    context 'default_timeout' do
      it 'allows setting and getting' do
        subject.default_timeout = :foo
        expect(subject.default_timeout).to eq :foo
      end
    end

    context 'default_port' do
      it 'allows setting and getting' do
        subject.default_port = :foo
        expect(subject.default_port).to eq :foo
      end
    end
  end

  describe '.config' do
    it 'yields a block if given' do
      expect do
        subject.config do |config|
          config.default_timeout = :foo
        end
      end.to change { subject.default_timeout }.from(subject.default_timeout).to(:foo)
    end
  end
end
