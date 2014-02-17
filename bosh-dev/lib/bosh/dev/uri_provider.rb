module Bosh::Dev
  class UriProvider
    PIPELINE_BUCKET  = ENV['BOSH_PIPELINE_BUCKET'] || 'bosh-ci-pipeline'
    ARTIFACTS_BUCKET = ENV['BOSH_ARTIFACTS_BUCKET'] || 'bosh-jenkins-artifacts'
    RELEASE_PATCHES_BUCKET = ENV['BOSH_RELEASE_PATCHES_BUCKET'] || 'bosh-jenkins-release-patches'
    S3_HOST = ENV['BOSH_S3_HOST'] || 's3.amazonaws.com'
    S3_PROTOCOL = ENV['BOSH_S3_PROTOCOL'] || 'http'

    def self.pipeline_uri(remote_directory_path, file_name)
      uri(PIPELINE_BUCKET, remote_directory_path, file_name)
    end

    def self.pipeline_s3_path(remote_directory_path, file_name)
      s3_path(PIPELINE_BUCKET, remote_directory_path, file_name)
    end

    def self.artifacts_uri(remote_directory_path, file_name)
      uri(ARTIFACTS_BUCKET, remote_directory_path, file_name)
    end

    def self.artifacts_s3_path(remote_directory_path, file_name)
      s3_path(ARTIFACTS_BUCKET, remote_directory_path, file_name)
    end

    def self.release_patches_uri(remote_directory_path, file_name)
      uri(RELEASE_PATCHES_BUCKET, remote_directory_path, file_name)
    end

    private

    def self.uri(bucket, remote_directory_path, file_name)
      parts = []
      parts << remote_directory_path unless remote_directory_path.nil? || remote_directory_path.empty?
      parts << file_name

      remote_file_path = parts.join('/')
      URI.parse("#{S3_PROTOCOL}://#{S3_HOST}/#{bucket}/#{remote_file_path}")
    end

    def self.s3_path(bucket, remote_directory_path, file_name)
      remote_file_path = File.join('/', remote_directory_path, file_name)
      "s3://#{bucket}#{remote_file_path}"
    end
  end
end
