require_relative "test_helper"

class ExtractDataTest < Minitest::Test

    def test_extract_list
        glim = GlimContext.new
        text = "Today is January 1, 2023."
        text << "John Smith is 32 years old, lives in New York."
        text << "His mother Emma was born in 1955, lives in New York too."
        text << "Albert Einstein was a genius and I wonder if you will fill in info."
        request = glim.request_from_template("extract_list", text: text)
        response = request.response
        assert response.extracted_data.length == 3
    end

    def test_extract_object
        glim = GlimContext.new
        req = glim.request(model_id: "gpt-3.5")
        req.set_output_schema({
            type: "object",
            properties: {
                name: { type: "string" },
                city_and_country: { 
                    type: "string",
                    description: "city where the person lives, followed by the country that city is in."
                },
                birth_year: { type: "integer" }
            },
            required: ["name"]
        })
        req.prompt = "John Blue was born in the year two thousand, has blue eyes, and lives in Brussels."
        response = req.response
        assert response.extracted_data[:name] == "John Blue"
    end

end