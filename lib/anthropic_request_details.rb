require 'tiktoken_ruby' # TODO only for token counting while anthropic doesn't support it

require 'anthropic'
#require_relative 'globals'

Anthropic.configure do |config|
  config.access_token = ENV.fetch('ANTHROPIC_API_KEY')
  config.request_timeout = 480 # Optional
end

# GlimRequest delegates to this
class AnthropicRequestDetails 
  
  def initialize(req)
    @req = req
  end
  
  attr_accessor :req

  def response_class
    AnthropicResponse
  end

  def llm_class_changed
    update_request_hash
  end

  def prompt_token_count
    # careful; for open_ai we want to look at messages[]
    update_request_hash
    req.count_tokens(req.request_hash[:prompt])
  end

  def forced_beginning_of_completion=(s)
    @forced_beginning_of_completion = s
    update_request_hash
  end
  attr_reader :forced_beginning_of_completion

  def message_history_as_string_for_claude
    s = ""
    if req.message_history
      for message in req.message_history
        if message[:role] == "user"
          s += "\n\nHuman: #{message[:content]}"
        elsif message[:role] == "system"
          s += "\n\nHuman: #{message[:content]}"
          s += "\n\nAssistant: Ok, understood!"
        elsif message[:role] == "assistant"
          s += "\n\nAssistant: #{message[:content]}"
        else
          putt :warning, "TODO - how to convert OpenAI role #{role} to Anthropic?"
        end
      end
    end
    return s
  end

  def update_request_hash
    prompt = message_history_as_string_for_claude
    @forced_beginning_of_completion ||= ""
    prompt += "\n\nHuman: #{req.prompt}" if req.prompt
    prompt += "\n\nAssistant:#{forced_beginning_of_completion}"

    req.request_hash[:max_tokens_to_sample] = req.max_tokens || 2000
    req.request_hash[:prompt] = prompt
    req.request_hash[:temperature] = req.temperature 
    req.request_hash[:model] = req.llm_name 
    # deeply remove keys for any values that are nil
    req.request_hash.delete_if { |k, v| v.nil? }
  end

end
