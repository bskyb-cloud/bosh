require 'bosh/director/core/templates'
require 'bosh/director/core/templates/rendered_job_template'
require 'bosh/director/core/templates/rendered_file_template'
require 'common/properties'

module Bosh::Director::Core::Templates
  class JobTemplateRenderer

    attr_reader :monit_erb, :source_erbs

    def initialize(name, monit_erb, source_erbs, logger)
      @name = name
      @monit_erb = monit_erb
      @source_erbs = source_erbs
      @logger = logger
    end

    def render(spec)
      template_context = Bosh::Common::TemplateEvaluationContext.new(spec)
      job_name = spec['job']['name']
      index = spec['index']

      monit = monit_erb.render(template_context, job_name, index, logger)

      rendered_files = source_erbs.map do |source_erb|
        file_contents = source_erb.render(template_context, job_name, index, logger)
        RenderedFileTemplate.new(source_erb.src_name, source_erb.dest_name, file_contents)
      end

      RenderedJobTemplate.new(name, monit, rendered_files)
    end

    private

    attr_reader :name, :logger
  end
end
