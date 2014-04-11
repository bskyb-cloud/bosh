require 'spec_helper'
require 'archive/tar/minitar'
require 'zlib'

describe 'director_scheduler', type: :integration do
  with_reset_sandbox_before_each

  def self.pending_for_travis_mysql!
    before do
      if ENV['TRAVIS'] && ENV['DB'] == 'mysql'
        pending 'Travis does not currently support mysqldump'
      end
    end
  end

  before do
    target_and_login
    bosh_runner.run('reset release', work_dir: TEST_RELEASE_DIR)
    bosh_runner.run('create release --force', work_dir: TEST_RELEASE_DIR)
    bosh_runner.run('upload release', work_dir: TEST_RELEASE_DIR)
    bosh_runner.run("upload stemcell #{spec_asset('valid_stemcell.tgz')}")

    deployment_hash = Bosh::Spec::Deployments.simple_manifest
    deployment_hash['jobs'][0]['persistent_disk'] = 20480
    deployment_manifest = yaml_file('simple', deployment_hash)
    bosh_runner.run("deployment #{deployment_manifest.path}")
    bosh_runner.run('deploy')
  end

  describe 'scheduled disk snapshots' do
    before { current_sandbox.scheduler_process.start }
    after { current_sandbox.scheduler_process.stop }

    it 'snapshots a disk on a defined schedule' do
      30.times do
        break unless snapshots.empty?
        sleep 1
      end

      keys = %w[deployment job index director_name director_uuid agent_id instance_id]
      snapshots.each do |snapshot|
        json = JSON.parse(File.read(snapshot))
        expect(json.keys - keys).to be_empty
      end

      expect(snapshots).to_not be_empty
    end

    def snapshots
      Dir[File.join(current_sandbox.agent_tmp_path, 'snapshots', '*')]
    end
  end

  describe 'scheduled backups' do
    pending_for_travis_mysql!

    before { current_sandbox.scheduler_process.start }
    after { current_sandbox.scheduler_process.stop }

    it 'backs up bosh on a defined schedule' do
      30.times do
        break unless backups.empty?
        sleep 1
      end

      expect(backups).to_not be_empty
    end

    def backups
      Dir[File.join(current_sandbox.sandbox_root, 'backup_destination', '*')]
    end
  end

  describe 'manual backup' do
    pending_for_travis_mysql!

    after { FileUtils.rm_f(tmp_dir) }
    let(:tmp_dir) { Dir.mktmpdir('manual-backup') }

    it 'backs up director logs, task logs, and database dump' do
      expect(bosh_runner.run('backup backup.tgz', work_dir: tmp_dir)).to match(/Backup of BOSH director was put in/i)

      files = tar_contents("#{tmp_dir}/backup.tgz")
      files.each { |f| expect(f.size).to be > 0 }
      expect(files.map(&:name)).to match_array(%w(logs.tgz task_logs.tgz director_db.sql blobs.tgz))
    end

    def tar_contents(tar_path)
      tar_entries = []
      tar_reader = Zlib::GzipReader.open(tar_path)
      Archive::Tar::Minitar.open(tar_reader).each do |entry|
        tar_entries << entry if entry.file?
      end
      tar_entries
    end
  end
end
