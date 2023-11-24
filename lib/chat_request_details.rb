require 'json-schema'
require 'net/http'

require 'openai'
require 'tiktoken_ruby'

require_relative 'globals'

# GlimRequest delegates to this
class ChatRequestDetails  # only for requests that involve a message array, like OpenAI  

  def initialize(request)
    @request = request
  end
  attr_accessor :request

  def response_class
    ChatResponse
  end

  def llm_class_changed
    update_request_hash
  end

  def update_request_hash
    request.request_hash[:temperature] = request.temperature / 2.0 if request.temperature # for some reason, OpenAI goes from 0 to 2, not 0 to 1
    request.request_hash[:max_tokens] = request.max_tokens
    request.request_hash[:model] = request.llm_name 
    
    #this is risky because it can overwrite things....

    if request.message_history
        messages = request.message_history.dup
    else
      messages = [{"role":"system","content":"You are a helpful assistant."}] 
    end
    # this could make sense, for example, if message_history
    # has a function call in it, along with the response to the function call that glim inserted
    # TODO: we might want to handle that case differently.
    if request.prompt
      messages.append({ role: 'user', content: request.prompt }) 
    end
    request.request_hash[:messages] = messages
  end

  def messages_as_string
    s = ""
    messages = request.request_hash[:messages] 
    if messages
      for message in messages
        role = message[:role]
        if ["user", "assistant", "system", "function"].include?(role)
          s += "\n\n#{role}: #{message[:content]}"
          if function_call = message[:function_call]
            s += "\nfunction_call: #{function_call[:name]}(#{function_call[:arguments]})"
          end
        else
          putt :warning, "TODO - how to convert OpenAI role #{role} to string?"
        end
      end
    end
    return s
  end   

  def prompt_token_count
    # careful; for open_ai we want to look at messages[]
    tc = request.count_tokens(messages_as_string)
    if request.request_hash[:functions]
      json = JSON.pretty_generate(request.request_hash[:functions])
      tc += request.count_tokens(json)
    end
    return tc
  end

  # functions / output schema


  # for convenience, if you want a list, you can specify the schema for the items
  def set_output_schema(output_schema, *flags)
    meta_schema = JSON::Validator.validator_for_name('draft4').metaschema
    begin
      JSON::Validator.validate!(meta_schema, output_schema)
      # putt :extract_data, 'The schema is valid.'        
      @output_schema = output_schema
    rescue JSON::Schema::ValidationError => e
      putt :extract_data, "The schema is not valid. Reason: #{e.message}"
      putt :extract_data, "Schema: #{output_schema}"
      raise
    end

    if flags.include?(:list)
      @output_schema = {
        type: 'object',
        properties: {
          list: {
            type: 'array',
            items: output_schema
          }
        }
      }
    end
  
    extract_data_function_name = 'extract_data'
    request.request_hash[:functions] = [{
      name: extract_data_function_name,
      description: "Extracts data from the user's message",
      parameters: @output_schema
    }]
    # Specifying a particular function via {"name":\ "my_function"} forces the model to call that function.
    request.request_hash[:function_call] = { "name": extract_data_function_name }
  end
  attr_reader :output_schema

  def expected_output_is_list?
    @output_schema && @output_schema[:type] == 'object' && @output_schema[:properties] && @output_schema[:properties][:list]
  end

  # function that in this request we offer to
  # the LLM API to call
  def set_functions_object(functions_object)
    @functions_object = functions_object
    # update_request_hash
    request.request_hash[:functions] = functions_object.class.ai_method_signatures_clean
    # [{
    #   name: extract_data_function_name,
    #   description: "Extracts data from the user's message",
    #   parameters: @output_schema
    # }]
  end

  def force_function_call(function_name)
    request.request_hash[:function_call] = { "name": function_name }
  end

  attr_reader :functions_object

  def to_s
    s = "ChatRequestDetails: "
    if output_schema
      schema = JSON.pretty_generate(output_schema)
      s += "\nSchema:\n#{schema}\n"
    end
    if functions_object
      s += "\nFunctions object: #{functions_object}"
    end
    return s
  end

end

