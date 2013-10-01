require 'bosh_agent/dir_copier'
require 'bosh_agent/disk_util'

module Bosh::Agent
  module Message

    # Migrates persistent data from the old persistent disk to the new
    # persistent disk.
    #
    # This message assumes that two mount messages have been received
    # and processed: one to mount the old disk at /var/vcap/store and
    # a second to mount the new disk at /var/vcap/store_migraton_target
    # (sic).
    class MigrateDisk < Base
      def self.long_running?; true; end

      def self.process(args)
        #logger = Bosh::Agent::Config.logger
        #logger.info("MigrateDisk:" + args.inspect)

        self.new.migrate(args)
        {}
      end

      def migrate(args)
        logger.info("MigrateDisk:" + args.inspect)
        @old_cid, @new_cid = args

        DiskUtil.umount_guard(store_path)

        mount_store(@old_cid, "-o ro") #read-only

        if check_mountpoints
          logger.info("Copy data from old to new store disk")
          migrator = DirCopier.new(store_path, store_migration_target)
          migrator.copy
        end

        DiskUtil.umount_guard(store_path)
        DiskUtil.umount_guard(store_migration_target)

        mount_store(@new_cid)
      end

      private
      def check_mountpoints
        Pathname.new(store_path).mountpoint? && Pathname.new(store_migration_target).mountpoint?
      end

      def mount_store(cid, options="")
        disk = Bosh::Agent::Config.platform.find_disk_by_cid(cid)
        logger.info("Mounting: #{disk.partition_path} #{store_path}")
        unless disk.mount(store_path, options)
          raise Bosh::Agent::MessageHandlerError, "Failed to mount: #{disk.partition_path} #{store_path} (exit code #{$?.exitstatus})"
        end
      end
    end
  end
end
