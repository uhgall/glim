require_relative "test_helper"
require_relative "../lib/globals"

require 'pp'

class AnomalyTest < Minitest::Test

    def test_anomaly

        glim = GlimContext.new
        req = glim.request(model_id: "llama2-7")
        req.prompt = "Who came up with the phrase 'Hello World?'"
        response = req.send_and_return_future.response
        response.add_anomaly(0.5, "Hello, anomaly!")
        
    end
end