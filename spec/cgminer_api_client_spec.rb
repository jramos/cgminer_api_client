require 'spec_helper'

describe CgminerApiClient do
  subject { CgminerApiClient }

  before do
    subject.default_timeout = 5
    subject.default_port = 4028
  end

  it 'should have a version constant with major.minor.patch' do
    expect(subject::VERSION).to_not be_empty
    expect(subject::VERSION.split(/\./).length).to eq(3)
  end

  context 'module attributes' do
    context 'default_timeout' do
      it 'should allow setting and getting' do
        subject.default_timeout = :foo
        expect(subject.default_timeout).to eq :foo
      end
    end

    context 'default_port' do
      it 'should allow setting and getting' do
        subject.default_port = :foo
        expect(subject.default_port).to eq :foo
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