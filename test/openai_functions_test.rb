# frozen_string_literal: true
# ^ Do we want that? 

require_relative 'test_helper'
require_relative '../lib/glim_ai_callable'

class WeatherStation
include AICallable

    ai_callable_as :get_current_weather do
      describe "Get the current weather in a given location"
      string :location, "The city and state, e.g. San Francisco, CA", required: true
      string :unit, "Temperature unit" , enum: %w[celsius fahrenheit]
    end
    def get_current_weather(location:, unit: "celsius")
      return "It's sunny in #{location}!"
    end
end


class OpenAiFunctionsTest < Minitest::Test
    def setup
      @ws = WeatherStation.new
      @glim = GlimContext.new
    end

    def glim
      @glim
    end
    
    def test_get_current_weather
      response = @ws._perform_ai_call(:get_current_weather, { :location => "San Francisco", :unit => "celsius" })
      assert_equal "It's sunny in San Francisco!", response
    end

    def test_generate_json_schema
        expected_schema = [
            {
              name: "get_current_weather",
              description: "Get the current weather in a given location",
              parameters: {
                type: "object",
                properties: {
                  location: {
                    type: :string,
                    description: "The city and state, e.g. San Francisco, CA"
                  },
                  unit: {
                    type: :string,
                    description: "Temperature unit",
                    enum: %w[celsius fahrenheit]
                  }
                },
                required: ["location"]
              }
            }
        ]
        schema = @ws.class.ai_method_signatures_clean
        expected = JSON.pretty_generate(expected_schema)
        actual = JSON.pretty_generate(schema)
        assert_equal expected, actual
    end
  
    def test_openai_calling_weather_station
        req = glim.request(model_id: "gpt-3.5")
        req.set_functions_object(WeatherStation.new)
        req.prompt = "How is the weather right now in San Francisco?"
        response = req.await_response
        putt(:functions, "REQUEST")
        putt(:functions, req)
        putt(:functions, "RESPONSE")
        # explicitly wait for the response
        putt(:functions, response.class )
    end
    
    def test_get_current_weather_no_location
      assert_raises(RuntimeError) do
        res = @ws._perform_ai_call(:get_current_weather, { "unit" => "celsius" })
        puts res
      end
    end

end
  