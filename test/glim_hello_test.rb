require_relative "test_helper"
require_relative "../lib/globals"

require 'pp'

class GlimTest < Minitest::Test

  def test_hello_world
    require 'glim_ai'
    glim = GlimContext.new
    response = glim.request(model_id: "gpt-3.5", prompt: "Who came up with Hello World?").await_response
    puts response.completion
    # and you get lots of nice things, like this:
    puts "Completion was #{response.completion_tokens} tokens long, total cost = $ #{response.total_cost}"  
  end
end
