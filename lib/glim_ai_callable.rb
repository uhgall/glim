


module AICallable

  def self.included(base)
    base.extend(ClassMethods)
  end

  module ClassMethods
    def ai_callable_as(method_name, &block)
      method_signature_builder = MethodSignatureBuilder.new
      method_signature_builder.instance_eval(&block)
      ai_method_signatures << method_signature_builder.signature.merge({ name: method_name.to_s })
    end

    def ai_method_signatures
      @ai_method_signatures ||= []
    end

    def ai_method_signatures_clean
      return @ai_method_signatures_clean if @ai_method_signatures_clean
      def remove_local_name(data)
        result = data.map do |item|
          { 
            'name' => item[:name],
            'description' => item[:description],
            'parameters' => {
              'type' => item[:parameters][:type],
              'properties' => item[:parameters][:properties].transform_values { |property| property.reject { |k, _| k == :local_name } },
              'required' => item[:parameters][:required]
            }
          }
        rescue => e
          putt :warning, "Issue with #{item}: #{e.message}"
          raise e
        end
        return result
      end
      sigs = ai_method_signatures # this is an array
      @ai_method_signatures_clean = remove_local_name(sigs)
    end
  
  end # ClassMethods

  def _perform_ai_call(eval_function_name, eval_function_arguments)
    # begin
      sigs = self.class.ai_method_signatures
      putt(:functions, "eval_function_name = #{eval_function_name}, sigs: #{sigs}")

      sig = sigs.select { |x| x[:name].to_s == eval_function_name.to_s }.first
      props = sig[:parameters][:properties]
      # props looks like this: {v1=>{...}, v2: {...}
      local_function_arguments = {}
      for ai_name in props.keys
        v = props[ai_name]
        # v looks like this:  {:type=>:string, :description=>"The expression, as a string, in correct ruby syntax", :local_name=>:exp}}
        local_param_name = v[:local_name]
        local_function_arguments[local_param_name] = eval_function_arguments[ai_name]
      end
      putt(:functions, "eval_function_arguments: #{eval_function_arguments}")
      putt(:functions, "local_function_arguments: #{local_function_arguments}")

      required_params = sig[:parameters][:required]
      for required_param in required_params
        raise "Missing required parameter: #{required_param}" unless eval_function_arguments[required_param]
      end
      # eval_function_result = eval_functions_object.send(eval_function_name, **local_function_arguments)
      eval_function_result = send(eval_function_name, **local_function_arguments)
    # rescue => e
    #   putt :warning, "FAILED Function call to #{self}.#{eval_function_name}(#{local_function_arguments}): #{e}"
    #   eval_function_result = e.message
    # end
    return eval_function_result
  end


  class MethodSignatureBuilder
    def initialize
      @signature = {
        parameters: {
          type: "object",
          properties: {},
          required: []
        }
      }
    end

    attr_reader :signature

    def describe(text)
      @signature[:description] = text
    end

#     4.2.1. Instance Data Model
# JSON Schema interprets documents according to a data model. A JSON value interpreted according to this data model is called an "instance".

# An instance has one of six primitive types, and a range of possible values depending on the type:

# null:
# A JSON "null" value
# boolean:
# A "true" or "false" value, from the JSON "true" or "false" value
# object:
# An unordered set of properties mapping a string to an instance, from the JSON "object" value
# array:
# An ordered list of instances, from the JSON "array" value
# number:
# An arbitrary-precision, base-10 decimal number value, from the JSON "number" value
# string:
# A string of Unicode code points, from the JSON "string" value

    def number(name, description, opts = {})
      # we want to use ai_name for everything here, but then when we invoke, 
      # we will want to look up the local name
      ai_name = opts[:ai_name] || name
      @signature[:parameters][:properties][ai_name] = {
        type: :number,
        description: description,
        local_name: name
      }
      if opts[:required]
        raise "Required muat be boolean if set" unless opts[:required].is_a?(TrueClass) || opts[:required].is_a?(FalseClass)
        @signature[:parameters][:required] << ai_name if opts[:required]
      end
    end

    def string(name, description, opts = {})
      # we want to use ai_name for everything here, but then when we invoke, 
      # we will want to look up the local name
      ai_name = opts[:ai_name] || name
      @signature[:parameters][:properties][ai_name] = {
        type: :string,
        description: description,
        local_name: name
      }
      if opts[:enum]
        rng = opts[:enum]
        for s in rng
          raise "Invalid enum value: #{s}" unless s.is_a?(String)
        end
        @signature[:parameters][:properties][ai_name][:enum] = rng
      end
      if opts[:required]
        raise "Required muat be boolean if set" unless opts[:required].is_a?(TrueClass) || opts[:required].is_a?(FalseClass)
        @signature[:parameters][:required] << ai_name if opts[:required]
      end
    end

  end
end
