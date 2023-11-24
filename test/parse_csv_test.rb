require_relative "test_helper"
require_relative "../lib/globals"

require 'pp'

class ParseCSVTest < Minitest::Test

    def test_simple_csv

        glim = GlimContext.new
        req = glim.request(model_id: "llama2-7")
        
        req.prompt = "Pay close attention: Respond with EXACTLY this:\n\n<CSV>\n0,0\n1,1\n2,4\n3,9\n</CSV>. So, a CSV file with 4 rows and 2 columns, in an XML tag."
        response = req.send_and_return_future.response
        assert_equal response.extract_csv_data_from_field, [["0","0"],["1","1"],["2","4"],["3","9"]]
        
    end
end