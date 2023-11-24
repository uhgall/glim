require_relative "test_helper"
require_relative "../lib/globals"

require 'pp'

class GlimTest < Minitest::Test

  def test_hello_world
    require 'glim_ai'
    glim = GlimContext.new
    r = glim.request(model_id: "gpt-3.5", prompt: "Hello World - Explain.").await_response
    r.completion
    #puts r.completion
    # and you get lots of nice things, like this:
    #puts "Completion had #{r.completion_tokens} tokens, cost $#{r.total_cost}" 
  end
end
