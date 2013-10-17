require 'spec_helper_system'

describe 'postgresql::repo:' do
  after :all do
    # cleanup after tests have ran
    puppet_apply("class { 'postgresql::globals': manage_package_repo => false }") do |r|
      r.exit_code.should_not == 1
    end
  end

  it 'test postgresql::repo class with manage_package_repo param on globals' do
    pp = <<-EOS.unindent
      class { 'postgresql::globals': manage_package_repo => true }
      class { 'postgresql::repo': }
    EOS

    puppet_apply(pp) do |r|
      r.exit_code.should_not == 1
      r.refresh
      r.exit_code.should == 0
    end
  end
end
