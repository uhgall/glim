require 'anthropic'

#require_relative 'globals'
#require 'tiktoken_ruby' # TODO only for token counting while anthropic doesn't support it

module Anthropic
  class NonWrappingClient < Client
    private
    def wrap_prompt(prompt:, prefix: "", suffix: "")
      prompt
    end
  end
end

class AnthropicResponse < GlimResponse

  def _process_raw_response
    raise "no raw response!" unless raw_response
    unless raw_response[:completion] 
      @error = "Anthropic API error: No completion!"
    end
  end

  def completion
    raw_response[:completion]
  end

  def self._count_tokens(llm_name, s)
    raise "can't count tokens in string that is nil" if s.nil?
    # TODO -- not yet support by ruby-anthropic
    # client = Anthropic::Client.new
    # puts "***** #{client.count_tokens(req.prompt)}"
    enc = Tiktoken.encoding_for_model("gpt-3.5-turbo") # this is obviously wrong, should use anthropic
    return enc.encode(s).length
  end

  def self.api_limiter
    @_api_limiter ||= APILimiter.new(max_concurrent_requests: 1)
  end

  def self.get_raw_response_from_api(request)
    # anthropic API modifies the prompt
    # but no need to params = Marshal.load(Marshal.dump(request.request_hash))
    # since it's only the prompt, we can just do this:
    params = request.request_hash.dup
    params[:prompt] = request.request_hash[:prompt].dup
    raise "request_hash should not have messages for Anthropic" if params[:messages]
    AnthropicResponse.api_limiter.with_limit do
      client = Anthropic::NonWrappingClient.new # this is necessary because the Anthropic API modifies the prompt
      _raw_response = client.complete(parameters: params).with_indifferent_access
      if _raw_response[:error]
        if _raw_response[:error][:type] == "rate_limit_error"
          # this shouldn't actually happen, since we pre-check the rate limit, so it's a hard error
          limit = AnthropicResponse.api_limiter.max_concurrent_requests
          raise RateLimitExceededError, "Rate limit (#{limit}) exceeded. Edit config or negotiate with Anthropic to avoid this."
        else
            # do nothing; the raw_response is clearly marked with an error. 
            # "Anthropic API error: #{_raw_response[:error]}"
        end
      end
      return _raw_response
    end
  end

  ##### NOT SUPPORTED in the code yet
  # top_k
  # integer
  # Only sample from the top K options for each subsequent token.
  # Used to remove "long tail" low probability responses. Learn more technical details here.
  
  # Anthropic does not report token counts so we use the number from the request
  def prompt_tokens
    request.prompt_token_count
  end

  # Anthropic does not report token counts so we count ourselves
  # NOTE: This means there may be some inaccuracies.
  def completion_tokens
    request.count_tokens(completion)
  end

  def responding_llm_name
    # anthropic doesn't have a notion of one model name pointing to another
    return request.llm_name
  end
  
  def error?
    @error
  end

end