
require_relative '../../lib/glim_ai'

class CalculatorService
include AICallable
  ai_callable_as :evaluate_expression do
    describe "Evaluates the given ruby expression and returns the result."
    string :exp, "The expression, as a string, in correct ruby syntax", ai_name: :expression_to_evaluate, required: true
  end
  def evaluate_expression(exp:)
    # Add validation logic here
    return eval(exp).to_s
  end

end

# puts CalculatorService.ai_method_signatures

glim = GlimContext.new

llm_name = "gpt-3.5-turbo"

calc = CalculatorService.new
raise "Calculator Service must be AICallable" unless calc.is_a?(AICallable)
puts "Let's test the calculator locally: "
exp = "   1+2"
puts exp + "=" + calc.send(:evaluate_expression, exp:).to_s

puts("And now let's get GPT to use it:")
req = glim.request(llm_name:)
req.set_functions_object(calc)

req.prompt = "What is the resistance of a 100m long copper cable that with a 6mm^2 cross section?"
puts "First question to GPT: #{req.prompt}"
response = req.response
puts "   response.completion:"
puts response.completion

# this will also invoke the function
new_req = response.create_request_with_function_result

# and now we send the request with the result of the function
# evaluation, so that the LLM can use that
new_response = new_req.response

puts("new_response.messages:")
puts(JSON.pretty_generate(new_response.messages))
puts "new_response.completion:"
puts new_response.completion
