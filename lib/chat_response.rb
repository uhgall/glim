
require 'json-schema'
require 'net/http'
require 'openai'
require 'tiktoken_ruby'

# require_relative 'glim_ai_callable'

# require_relative 'globals'

OpenAI.configure do |config|
  config.access_token = ENV.fetch('OPENAI_API_KEY')
  config.request_timeout = 480 # Optional
end

class ChatResponse < GlimResponse


  def _process_raw_response
    raise "no raw response!" unless raw_response
    # TODO
    # request has message_history
    # response has messages_sent (still need reader)
    # and then what does the following look like? 
    if !raw_response[:error]
      @message = raw_response.dig(:choices, 0, :message) 
      @messages = messages_sent.dup + [@message]
      if function_call_message?
        log_function_call_message
      end
    else
      # yeah there was an error. nothing to do here, though
    end
  end

  def self._count_tokens(llm_name, s)
    enc = Tiktoken.encoding_for_model(llm_name)
    if !enc
      # putt :warning, "Tiktoken doesn't know model #{llm_name}"
      enc = Tiktoken.encoding_for_model("gpt-3.5")
    end
    return enc.encode(s).length
  end

  def self._placeholder_anyscale_api_call(params)
    # for some reason the ruby gem for OpenAI won't work with anyscale
    # so we're doing it manually for now
    key = ENV.fetch('ANYSCALE_API_KEY')
    # for some reason, this doesn't work, just returns "details: Not found"
    # client = OpenAI::Client.new(uri_base: "https://api.endpoints.anyscale.com/v1", access_token: key)
    # @raw_response = deep_symbolize_keys(cached_response || client.chat(parameters: params))
    api_base = "https://api.endpoints.anyscale.com/v1"
    uri = URI("#{api_base}/chat/completions")
    r = Net::HTTP::Post.new(uri, 'Content-Type' => 'application/json', 'Authorization' => "Bearer #{key}")
    r.body = params.to_json
    http = Net::HTTP.new(uri.host, uri.port)
    http.read_timeout = 480  # seconds
    http.use_ssl = true if uri.scheme == 'https'
    response = http.request(r)
    if response.code != "200"
      return { error: { message: "Error from AnyScale: #{response.code} #{response.body}" }}.with_indifferent_access
    else
      return JSON.parse(response.body).with_indifferent_access
    end
  end

  # this blocks
  def self.get_raw_response_from_api(request)
    glim_model = request.glim_model || err("no glim_model set!")
    api_limiter = APILimiter.new(max_concurrent_requests: 2)
    _raw_response = nil
    api_limiter.with_limit do
      putt :rpc, "Sending request to #{glim_model.provider} API"
      if glim_model.provider == "openai"
        client = OpenAI::Client.new
        _raw_response = client.chat(parameters: request.request_hash).with_indifferent_access
      else
        _raw_response = _placeholder_anyscale_api_call(request.request_hash).with_indifferent_access
      end
      if _raw_response[:error]
        if _raw_response[:error][:type] == "rate_limit_error"
          # this shouldn't actually happen, since we pre-check the rate limit, so it's a hard error
          limit = api_limiter.max_concurrent_requests
          raise RateLimitExceededError, "Rate limit (#{limit}) exceeded. Edit config or negotiate with service provider to avoid this."
        else
          # we actually want to pass this back to the user's thread instead of raising an error here
          putt :info, "Error. Prompt was a #{request.prompt.class}. Error = #{_raw_response[:error].inspect}"
        end
      end
    end
    return _raw_response
  end

  def error?
    error != nil
  end

  def error
    raw_response[:error]
  end

  def function_call_message?
    @message[:function_call] != nil
  end

  def _function_call_from_message
    @message[:function_call] || err("No function call!")
  end

  def completion
    raise_if_error
    @message[:content] 
    # || raise_error("No error, but completion was nil")
    # BEFORE NOV 2023, turns out there is always a completion, even with function calls
    # not any more, though
  end

  def _function_call_arguments_from_message
    begin 
      s = _function_call_from_message[:arguments]
      if s[0] == "{" || s[0] == "["
        JSON.parse(s).with_indifferent_access
      else
        raise "OpenAI asked to call a function, but the arguments were not JSON: #{s}"
      end
    rescue   => e
      request.save_log_file("json_error.json", s)
      raise_error(e)
    end
  end

  def function_name_from_message
    _function_call_from_message[:name]
  end

  def log_function_call_message
    s = "LLM requested results of function call to #{request.functions_object}##{function_name_from_message}\n"
    s += JSON.pretty_generate(_function_call_arguments_from_message)
    request.save_log_file("function_call.txt", s)
  end

  # returns a new GlimRequest that is preloaded with the data for
  # sending the results of a function call back to the LLM API
  def create_request_with_function_result

    eval_functions_object = request.functions_object || err("No functions_object")
    raise "functions_object must be ai_callable, is #{eval_functions_object}" unless eval_functions_object.is_a?(AICallable)

    eval_function_name = _function_call_from_message[:name].to_sym
    raise "no_method_error #{eval_function_name}" unless eval_functions_object.respond_to?(eval_function_name)

    # TODO -- validate that the schema is right? 
    eval_function_arguments = _function_call_arguments_from_message

    putt :functions, "#{eval_functions_object}.#{eval_function_name}(#{eval_function_arguments})"
    eval_function_result = eval_functions_object._perform_ai_call(eval_function_name, eval_function_arguments)

    return create_request_for_chat(message_to_append: {
      role: "function",
      name: eval_function_name,
      content: eval_function_result.to_json
    })
  end

  # todo - would it make more sense to just return the messages
  # and then the caller makes the new request? not sure. 
  def create_request_for_chat(message_to_append: nil)
    h = request.generic_params_hash.merge({
      model_id: request.model_id,
      context: request.context
    })
    new_request = GlimRequest.new(**h)
    new_request.message_history = messages.dup

    if message_to_append
      messages.append(message_to_append)
    end

    new_request.request_hash[:messages] = messages
    new_request

  end

  # the message generated by GPT
  def message
    @message 
  end

  # all messages: prior ones, the prompt, GPT's response, and the function call, if it happened
  def messages
    @messages
  end

  # the extracted data generated by GPT
  def extracted_data
    return @extracted_data if @extracted_data
    raise "no output schema specified, can't get extracted_data" unless request.output_schema
    args = _function_call_arguments_from_message
    JSON::Validator.validate!(request.output_schema, args)
    if request.expected_output_is_list? # TODO -- this feels a bit awkward
      @extracted_data = args[:list] || raise_error("Expected list")
    else
      @extracted_data = args
    end
    @extracted_data
  end

  def messages_sent
    request.request_hash[:messages] 
  end

  def usage
    raw_response[:usage] || err("No usage in Response")
  end

  def prompt_tokens
    usage[:prompt_tokens]
  end

  def completion_tokens
    usage[:completion_tokens]
  end

  def responding_llm_name
    raw_response[:model]
  end

  def inspect
    "<ChatResponse to #{request},  #{completion}"
  end

end



######## OpenAI only - TODO
# maybe put this in a hash called ai.open_ai ?

# n
# integer or null
# Optional
# Defaults to 1
# How many chat completion choices to generate for each input message.

#-------

# presence_penalty
# number or null
# Optional
# Defaults to 0
# Number between -2.0 and 2.0. Positive values penalize new tokens based on whether they appear in the text so far, increasing the model's likelihood to talk about new topics.
# See more information about frequency and presence penalties.

# frequency_penalty
# number or null
# Optional
# Defaults to 0
# Number between -2.0 and 2.0. Positive values penalize new tokens based on their existing frequency in the text so far, decreasing the model's likelihood to repeat the same line verbatim.
# See more information about frequency and presence penalties.

# logit_bias
# map
# Optional
# Defaults to null
# Modify the likelihood of specified tokens appearing in the completion.
# Accepts a json object that maps tokens (specified by their token ID in the tokenizer) to an associated bias value from -100 to 100. Mathematically, the bias is added to the logits generated by the model prior to sampling. The exact effect will vary per model, but values between -1 and 1 should decrease or increase likelihood of selection; values like -100 or 100 should result in a ban or exclusive selection of the relevant token.


      # "none" means the model does not call a function, and responds to the end-user.
      # "auto" means the model can pick between an end-user or calling a function.
      # Specifying a particular function via {"name":\ "my_function"} forces the model to call that function.
      # "none" is the default when no functions are present. "auto" is the default if functions are present.