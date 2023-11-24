require_relative "test_helper"
require_relative "../lib/globals"

class GlimTest < Minitest::Test

  def test_caching
    model_ids =  ["claude-instant-1"]
    glim = GlimContext.new
    response = {} # llm -> response
    for model_id in model_ids
      request = glim.request_from_template("simple_question", question: "How do you make a pizza?")
      request.model_id = model_id
      response[model_id]  = request.send_and_return_future.response
    end
    putt :cache, "*** Checking that results were reasonable"
    for model_id in model_ids 
      assert response[model_id].completion.include?("pizza")
    end
    putt :cache, "*** Running it again, now it should be cached"
    for model_id in model_ids
      question = "How do you make a pizza?"
      request = glim.request_from_template("simple_question", question:)
      request.model_id = model_id
      assert request.maybe_cached_response
      response = request.send_and_return_future.response
      assert response.cached?
    end
  end

  # this illustrates send_and_on_response
  def test_caching_no_template
    prompt = "How do you make a pizza?"
    model_ids =  ["claude-instant-1"]
    glim = GlimContext.new
    for model_id in model_ids
      res = glim.request(model_id:, prompt:).send_and_on_response do |response|
        assert response.completion.include?("pizza")  
      end
      # ok but now we need to wait so that the response gets cached
      res.response
    end

    putt :cache, "*** Running it again, now it should be cached"
    for model_id in model_ids
      request = glim.request(model_id:, prompt:)
      assert request.send_and_return_future.cached?
      assert request.send_and_return_future.response.cached?
      # do not send it off; just need one to check if this is cached
    end
  end

  def test_anthropic_token_hint
    glim = GlimContext.new
    request = glim.request_from_template("simple_question", question: "How do you make a pizza?")
    request.model_id =  "claude-instant-1"
    request.forced_beginning_of_completion = "Go ahead, and find a se"
    response  = request.response
    putt :cache, "*** Checking that results were reasonable"
    assert response.completion.include?("pizza")    
  end

  def test_token_counts_are_correct
    model_id =  "gpt-3.5"
    glim = GlimContext.new
    request = glim.request(model_id: )
    request.prompt = "How do you make pizza?"
    assert_equal 17, request.prompt_token_count
    response = request.response
    t = response.prompt_tokens
    assert_equal t, request.prompt_token_count+6 # TODO - the diff is probably the default initial message.
  end

  def test_chat
    model_id =  "gpt-3.5"
    glim = GlimContext.new
    request = glim.request(model_id:)
    request.prompt = "How do you make pizza?"
    response = request.response
    s = response.completion
    
    req2 = response.create_request_for_chat
    req2.prompt = "In the style of marxist leninist propaganda please."
    response2 = req2.response
    s += response2.completion

    req3 = response2.create_request_for_chat
    req3.prompt = "And now in LOLspeak please."
    response3 = req3.response
    s += response3.completion

  end
end
