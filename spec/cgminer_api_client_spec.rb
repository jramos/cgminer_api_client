require 'spec_helper'

describe CgminerApiClient do
  subject { CgminerApiClient }

  before do
    subject.default_timeout = 5
  end

  it 'should have a version constant' do
    subject::VERSION
  end

  context 'module attributes' do
    context 'default_timeout' do
      it 'should allow setting and getting' do
        subject.default_timeout = :foo
        expect(subject.default_timeout).to eq :foo
      end
    end
  end

  context '.config' do
    it 'should yield a block if given' do
      expect {
        subject.config do |config|
          config.default_timeout = :foo
        end
      }.to change { subject.default_timeout }.from(subject.default_timeout).to(:foo)
    end
  end
end