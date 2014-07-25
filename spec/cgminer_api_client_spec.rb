require 'spec_helper'

describe CgminerApiClient do
  subject { CgminerApiClient }

  it 'should have a version constant' do
    subject::VERSION
  end
end