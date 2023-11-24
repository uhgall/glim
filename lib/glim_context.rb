require_relative 'globals'

class GlimContext

    attr_reader :log_name, :template_subdir, :default_llm_name
    attr_reader :start_time

    def initialize(log_name: nil, template_subdir: "templates", default_llm_name: nil)

        #["test/test_glim.rb:71:in `new'",
        if !log_name
            @log_name = caller[0].split(':').first.split('/').last
        else
            @log_name = log_name
        end
        @log_name += "-"+Time.now.strftime('%Y-%m-%d-%H-%M-%S')
        @template_subdir = template_subdir
        @default_llm_name = default_llm_name
        putt :log, "GlimContext template_subdir=#{@template_subdir}, log_name: #{log_name.inspect}"
        @start_time = Time.now
    end

    def request(args)
        args_with_context = args.merge(context: self)
        r = GlimRequest.new(**args_with_context)
        #r.glim_model ||= default_llm_name
        return r
    end

    def request_from_template(template_name, **template_args)
        request = GlimRequest.new(context: self)
        request.process_template(template_name, **template_args)
        request.context = self
        request
    end

    # just for convenience
    def response_from_template(template_name, **template_args)
        # puts("response_from_spec: #{template_args.inspect}")
        req = request_from_template(template_name, **template_args)
        req.response
    end

    def all_models_openai
        client = OpenAI::Client.new
        return client.models.list["data"]
    end

    def model_list_openai
        all_models_openai.map{|m| m["id"]}.select {|m| m.include?("gpt")}.sort
    end

    def log_base_glim
        self.class.log_base_glim
    end

    def log_base
        File.join(log_base_glim,log_name)
    end

    def anomaly_base_glim
        self.class.anomaly_base_glim
    end

    def anomaly_base
        File.join(anomaly_base_glim,log_name)
    end

    def cache_path
        self.class.cache_path
    end

    def log_line_to_summary(line)
        log_summary_file = File.join(log_base, "llm_log.csv")
        seconds_since_start = Time.now - start_time
        s = "#{seconds_since_start.round(3)}, #{line}"
        File.open(log_summary_file, 'a') do |f|
          f.puts s
        end
    end

    def _add_to_cost(cost,opts)
        @cost ||= 0.0
        @cost += cost unless opts[:cached]
        @cost_including_cached ||= 0.0
        @cost_including_cached += cost
    end

    def cost
        @cost || 0
    end

    def cost_including_cached
        @cost_including_cached || 0
    end

    class << self
        def cleanup!(target)
            cleanup_path = case target.to_s.to_sym
            when :log
                log_base_glim
            when :anomaly
                anomaly_base_glim
            when :cache
                cache_path
            else
                raise "Unknown cleanup target: #{target}, it must be one of log, anomaly, cache"
            end

            puts "Removing #{cleanup_path}"
            FileUtils.rm_rf(cleanup_path)
            puts "Done."
        end

        def log_base_glim
            ENV['GLIM_LOG_DIRECTORY'] || raise("Set GLIM_LOG_DIRECTORY to a directory where you want to store logs")
        end

        def anomaly_base_glim
            ENV['GLIM_ANOMALY_DIRECTORY'] || raise("Set GLIM_ANOMALY_DIRECTORY to a directory where you want to store anomaly logs")
        end

        def cache_path
            ENV['GLIM_CACHE_DIRECTORY'] || raise("Set GLIM_CACHE_DIRECTORY to a directory where you want to store cached responses")
        end
    end
end

