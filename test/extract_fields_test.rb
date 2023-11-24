

require 'minitest/autorun'
require_relative '../lib/globals.rb'

class ExtractFieldsTest < Minitest::Test
  def test_extract_fields
    input = '<greet>Hello</greet><name>Ruby</name>'
    result = extract_fields(input)
    assert_equal({ "greet" => "Hello", "name" => "Ruby" }, result)

    # Case with empty string
    input = ''
    result = extract_fields(input)
    assert_equal({}, result)

    # Case without any tags
    input = 'Hello Ruby'
    result = extract_fields(input)
    assert_equal({}, result)

    # # Case with nested tags
    # input = '<greet><salutation>Hello</salutation><name>Ruby</name></greet>'
    # result = extract_fields(input)
    # assert_equal({ "salutation" => "Hello", "name" => "Ruby" }, result) 

    # Case with malformed tags (missing closing tag)
    input = '<greet>Hello<name>Ruby'
    result = extract_fields(input)
    assert_equal({}, result)
    
    # Case with tags containing attributes
    input = '<greet type="morning">Hello</greet><name>Ruby</name>'
    result = extract_fields(input)
    assert_equal({ "greet" => "Hello", "name" => "Ruby" }, result)
    
    # Case with multiple same tags, considering only the last occurrence
    input = '<greet>Hello</greet><greet>Hi</greet><name>Ruby</name>'
    result = extract_fields(input)
    assert_equal({ "greet" => "Hi", "name" => "Ruby" }, result)

  end
end

