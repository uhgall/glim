require 'json-schema'
require 'erb'

require_relative 'globals'
require_relative 'glim_helpers'



require_relative 'chat_request_details'
require_relative 'chat_response'

class GlimRequest

  attr_accessor :temperature, :top_p, :max_tokens, :stop
  attr_accessor :forced_beginning_of_completion
  attr_accessor :glim_model

  attr_accessor :no_cache, :prefer_cached_response

  attr_accessor :context
  attr_reader :template_name, :template_text
  attr_reader :message_history
  
  attr_reader :request_hash
  # this is the data structure the response class will send over the network
  # the cache key is generated from this. 

  def initialize(**args)
    @prefer_cached_response = true
    @logged_something = false
    args.each do |k, v| 
      if k == :model_id
        @glim_model = GlimAI.model(v) 
        raise "No model found for #{v}" unless @glim_model
      elsif k == :glim_model
        raise "glim_model must be a GlimModel" unless v.is_a?(GlimModel)
        @glim_model = v    
      elsif k == :prompt
        @prompt = v
      elsif k == :context
        @context = v
      elsif k == :temperature
        @temperature = v
      elsif k == :top_p
        @top_p = v
      elsif k == :max_tokens
        @max_tokens = v
      elsif k == :stop
        @stop = v
      elsif k == :no_cache
        @no_cache = v
      elsif k == :prefer_cached_response
        @prefer_cached_response = v
      else
        raise "Unknown parameter #{k}"
      end
    end
    @request_hash = {}
    if glim_model
      request_details.llm_class_changed
    end
    @temperature ||= 0
  end

  # the full name of the model, usually a bit long and not what you'd want in your code
  def llm_name 
    glim_model[:llm_name]
  end

  def model_id
    glim_model[:model_id]
  end

  def model_id=(id)
    @glim_model = GlimAI.model(id)
    raise "No model found for #{id}" unless @glim_model
    request_details.llm_class_changed
  end

  # prompt and messages

  attr_reader :prompt
  def prompt=(p)
    @prompt = p
    request_details.update_request_hash
    save_log_file("prompt.txt", prompt)
  end

  def message_history=(messages)
    @message_history = messages
    request_details.update_request_hash
  end

  def replace_initial_system_message(system_message)
    @message_history ||= []
    @message_history[0] ||=  {
      "role": "system",
      "content": system_message
    }
    request_details.update_request_hash
  end
 
  # logging

  def log_base_this_request
    @log_base_this_request ||= begin   
      subdir = File.join(context.log_base, log_name_this_request)
      FileUtils.mkdir_p(subdir) unless Dir.exist?(subdir)
      putt :log, "Log path: #{@log_base_this_request}"
      subdir
    end
  end

  def anomaly_base_this_request
    @anomaly_base_this_request ||= begin   
      subdir = File.join(context.anomaly_base, log_name_this_request)
      FileUtils.mkdir_p(subdir) unless Dir.exist?(subdir)
      putt :log, "Anomaly Log path: #{subdir}"
      subdir
    end
  end

  def log_name_this_request
    @log_name_this_request ||= begin
      timestamp = Time.now.strftime('%a-%H:%M:%S.%3N')
      template_name_sanitized = (template_name || "no_template").gsub(/[^0-9A-Za-z.\-]/, '_')
      "#{timestamp}-#{template_name_sanitized}"
    end
  end

  attr_writer :log_name_this_request

  def save_log_file(section_name, content)
    file_path = File.join(log_base_this_request, section_name)
    putt(:log, "Saving to: #{file_path}")
    File.write(file_path, content)
    
    log_dir = ENV['GLIM_LOG_DIRECTORY']
    if !@logged_something
      @logged_something = true
      last_all_files = File.join(log_dir,"_last","*")
      #puts "deleting #{last_all_files}"
      Dir.glob(last_all_files).each do |file|
        File.delete(file) if File.file?(file)
      end
    end
    last_file = File.join(log_dir,"_last",section_name)
    FileUtils.mkdir_p(File.dirname(last_file)) unless Dir.exist?(File.dirname(last_file))
    File.write(last_file, content)
    return file_path
  end

  # templates
  
  def process_template(template_name, **template_args)
    # TODO - think through how to handle paths
    # basedir = File.dirname(File.expand_path($PROGRAM_NAME))

    for c in caller
      calling_file = c.split(':').first
      break unless calling_file && calling_file.include?("/lib")
    end
    dir_path = File.dirname(calling_file)
    template_path = File.join(dir_path, 'templates', "#{template_name}.erb")

    unless File.exist?(template_path)
      raise "Template #{template_name} not found: #{template_path}"
    end

    putt :config, template_path
    
    template_text = File.read(template_path)
    template = ERB.new(template_text)
    wrapper = Object.new
    wrapper.extend(GlimHelpers) 
    template_args.each do |key, value|
      wrapper.define_singleton_method(key) { value }
    end  
    req_instance = self # this way, we can access it in the define_method below
    wrapper.define_singleton_method(:req) { req_instance } # caution: can't use self directly here, otherwise self == wrapper
    @prompt = template.result(wrapper.instance_eval { binding })
    @template_name = template_name
    @template_text = template_text
    request_details.update_request_hash if glim_model
    save_log_file("template_text.txt", template_text)
    save_log_file("prompt.txt", prompt)
    return self
  end

  def count_tokens(s)
    response_class._count_tokens(llm_name, s)
  end

  def cost_per_prompt_token
    glim_model.cost_per_prompt_token
  end

  def  cost_per_completion_token
    glim_model.cost_per_completion_token
  end

  def context_length
    glim_model.context_length
  end

  def total_tokens_token_count
    prompt_token_count + max_tokens
  end

  def min_cost
    return cost_per_prompt_token * prompt_token_count 
  end

  def max_cost
    return cost_per_prompt_token * prompt_token_count + cost_per_completion_token * max_tokens
  end

  def cache_key
    key = Digest::SHA1.hexdigest(request_hash.to_json)
    putt :cache, "Computed cache key: #{key}"
    return key
  end 

  def maybe_cached_response
    cache_file = File.join(context.cache_path, "#{cache_key}.json")
    if File.exist?(cache_file)
      putt :cache, "Cached Response found for key: #{cache_key}"
      return (JSON.parse(File.read(cache_file)).with_indifferent_access)
    else
      putt :cache, "No cached Response found for key: #{cache_key}"
      return nil
    end
  end

  # this will create a response and, unless it's cached, send off the request to the API
  def send_and_return_future
    return GlimResponseFuture.new(self)
  end

  # this will create a response and, unless it's cached, send off the request to the API
  def send_and_on_response(&block)
    return GlimResponseFuture.new(self, &block)
  end

  # deprecated
  def response
    await_response
  end

  def await_response
    return send_and_return_future.await_response
  end

  def to_s
    s = "Req to #{model_id}"
    s += " from #{template_name}" if template_name
    s += request_details.to_s if request_details
  end
  
  def inspect
    "#<GlimRequest: prompt_size=#{@prompt ? @prompt.size : 'nil'}, template_name=#{@template_name}>"
  end

  def method_missing(method_name, *args, &block)
    raise "No method #{method_name} in #{self.class}. Args were: #{args}" unless request_details
    if request_details.respond_to?(method_name)
      request_details.send(method_name, *args, &block)
    else
      raise "No method #{method_name} in #{request_details.class}."
    end
  end

  def request_details
    @request_details ||= glim_model&.klass&.new(self)
  end

  def response_class
    @request_details.response_class
  end 

  def generic_params_hash
    {
      temperature: temperature,
      top_p: top_p,
      max_tokens: max_tokens,
      stop: stop
    }
  end


end
