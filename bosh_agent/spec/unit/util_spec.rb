require 'spec_helper'
require 'common/exec'
require 'tmpdir'

describe Bosh::Agent::Util do
  before do
    Bosh::Agent::Config.blobstore_provider = 'simple'
    Bosh::Agent::Config.blobstore_options = {}
  end

  before { HTTPClient.stub(new: httpclient) }
  let(:httpclient) { instance_double('HTTPClient') }

  describe '#unpack_blob' do
    it 'should unpack a blob' do
      response = double('response')
      response.stub(:status).and_return(200)

      get_args = ['/resources/some_blobstore_id', {}, {}]
      httpclient
        .should_receive(:get)
        .with(*get_args)
        .and_yield(dummy_package_data)
        .and_return(response)

      install_dir = File.join(Bosh::Agent::Config.base_dir, 'data', 'packages', 'foo', '2')
      blobstore_id = 'some_blobstore_id'
      sha1 = Digest::SHA1.hexdigest(dummy_package_data)

      Bosh::Agent::Util.unpack_blob(blobstore_id, sha1, install_dir)
    end

    it "should raise an exception when sha1 is doesn't match blob data" do
      response = double('response')
      response.stub(:status).and_return(200)

      get_args = ['/resources/some_blobstore_id', {}, {}]
      httpclient
        .should_receive(:get)
        .with(*get_args)
        .at_least(:once)
        .and_yield(dummy_package_data)
        .and_return(response)

      install_dir = File.join(Bosh::Agent::Config.base_dir, 'data', 'packages', 'foo', '2')

      expect {
        Bosh::Agent::Util.unpack_blob('some_blobstore_id', 'bogus_sha1', install_dir)
      }.to raise_error(Bosh::Agent::MessageHandlerError, /sha1 mismatch/)
    end
  end

  it 'should return a binding with config variable' do
    config_hash = { 'job' => { 'name' => 'funky_job_name' } }
    config_binding = Bosh::Agent::Util.config_binding(config_hash)

    template = ERB.new('job name: <%= spec.job.name %>')

    expect {
      template.result(binding)
    }.to raise_error(NameError)

    template.result(config_binding).should == 'job name: funky_job_name'
  end

  it 'should handle hook' do
    base_dir = Bosh::Agent::Config.base_dir

    job_name = 'hubba'
    job_bin_dir = File.join(base_dir, 'jobs', job_name, 'bin')
    FileUtils.mkdir_p(job_bin_dir)

    hook_file = File.join(job_bin_dir, 'post-install')

    File.exists?(hook_file).should be_false
    expect(Bosh::Agent::Util.run_hook('post-install', job_name)).to be_nil

    File.open(hook_file, 'w') do |fh|
      fh.puts("#!/bin/bash\necho -n 'yay'") # sh echo doesn't support -n (at least on OSX)
    end

    expect {
      Bosh::Agent::Util.run_hook('post-install', job_name)
    }.to raise_error(
      Bosh::Agent::MessageHandlerError,
      "`post-install' hook for `hubba' job is not an executable file",
    )

    FileUtils.chmod(0700, hook_file)
    Bosh::Agent::Util.run_hook('post-install', job_name).should == 'yay'
  end

  it 'should return the block device size' do
    block_device = '/dev/sda1'
    File.should_receive(:blockdev?).with(block_device).and_return true
    Bosh::Agent::Util
      .should_receive(:sh)
      .with("/sbin/sfdisk -s #{block_device} 2>&1")
      .and_return(Bosh::Exec::Result.new('/sbin/sfdisk -s #{block_device} 2>&1', '1024', 0))
    Bosh::Agent::Util.block_device_size(block_device).should == 1024
  end

  it 'should raise exception when not a block device' do
    block_device = '/dev/not_a_block_device'
    File.should_receive(:blockdev?).with(block_device).and_return false
    expect {
      Bosh::Agent::Util.block_device_size(block_device)
    }.to raise_error(Bosh::Agent::MessageHandlerError, 'Not a blockdevice')
  end

  it 'should raise exception when output is not an integer' do
    block_device = '/dev/not_a_block_device'
    File.should_receive(:blockdev?).with(block_device).and_return true
    Bosh::Agent::Util
      .should_receive(:sh)
      .with("/sbin/sfdisk -s #{block_device} 2>&1")
      .and_return(Bosh::Exec::Result.new('/sbin/sfdisk -s #{block_device} 2>&1', 'foobar', 0))
    expect {
      Bosh::Agent::Util.block_device_size(block_device)
    }.to raise_error(Bosh::Agent::MessageHandlerError, 'Unable to determine disk size')
  end

  it 'should return the network info' do
    sigar = double('SigarBox')
    net_info = double('net_info')
    ifconfig = double('ifconfig')
    Bosh::Agent::SigarBox.stub(:create_sigar).and_return(sigar)

    sigar.should_receive(:net_info).and_return(net_info)
    sigar.should_receive(:net_interface_config).with('eth0').and_return(ifconfig)
    net_info.should_receive(:default_gateway_interface).and_return('eth0')
    net_info.should_receive(:default_gateway)
    ifconfig.should_receive(:address)
    ifconfig.should_receive(:netmask)

    network_info = Bosh::Agent::Util.get_network_info
    expect(network_info).to have_key('ip')
    expect(network_info).to have_key('netmask')
    expect(network_info).to have_key('gateway')
  end

  describe '.create_symlink' do
    before do
      @workspace = Dir.mktmpdir
      @old_name = File.join(@workspace, 'old')
      @new_name = File.join(@workspace, 'new')
      FileUtils.mkpath(@old_name)
    end
    after { FileUtils.rm_r(@workspace) }

    context 'when destination does not exist' do
      it 'creates a symlink at dst pointing to src' do
        expect {
          Bosh::Agent::Util.create_symlink(@old_name, @new_name)
        }.to change { File.symlink?(@new_name) }.from(false).to(true)
        File.readlink(@new_name).should eq(@old_name)
      end
    end

    context 'when destination exist and points to a directory' do
      # This is what FileUtils#ln_sf SHOULD do but sadly does not
      it 'replaces the existing link' do
        second_target = File.join(@workspace, 'jazz')
        Bosh::Agent::Util.create_symlink(@old_name, @new_name)
        Bosh::Agent::Util.create_symlink(second_target, @new_name)

        expect(File.readlink(@new_name)).not_to eq(@old_name)
      end
    end
  end
end
