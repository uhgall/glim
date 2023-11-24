

require_relative "test_helper"

class GlobalsTest < Minitest::Test

    def test_deep_copy_with_mods
        input_hash = {
            key1: "A string that is too long",
            key2: [1, 2, 3, 4, 5],
            key3: { inner_key: "Another long string" },
            key4: [1,2]
        }
        string_cutoff = 10
        array_cutoff = 3        
        output_hash = deep_copy_with_mods(input_hash, string_cutoff, array_cutoff)
        expected = {
            :key1=>"A string t..b35c02f5 25b}", 
            :key2=>[1, 2, 3, ["... (2 more)"]], 
            :key3=>{:inner_key=>"Another lo..93a5425e 19b}"}, 
            :key4=>[1, 2]
        }
        assert_equal expected, output_hash
    end

    def test_extract_between_markers
        assert_equal "content", extract_between_markers("[start]content[end]", "[start]", "[end]")
        assert_nil extract_between_markers("[start]content", "[start]", "[end]")
        assert_nil extract_between_markers("content[end]", "[start]", "[end]")
    end
    
    def test_extract_with_markers
        assert_equal "[start]content[end]", extract_with_markers("[start]content[end]", "[start]", "[end]")
        assert_equal "{\nfoo\n}", extract_with_markers("blah \n{\nfoo\n}\n\n\n", "{", "}")
        assert_nil extract_with_markers("[start]content", "[start]", "[end]")
        assert_nil extract_with_markers("content[end]", "[start]", "[end]")
    end

end