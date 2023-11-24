require_relative '../../lib/glim_ai'

glim = GlimContext.new(log_name: "ask_all")
# these first two lines above are the only ones that you need to add to your code

# in this example, we will want to compare the answers of these different models
models =  ["claude-instant-1",  "gpt-3.5-turbo"]

# we will ask this question to each model
question = "If, in some cataclysm, all of scientific knowledge were to be destroyed, and only one sentence passed on to the next generation of creatures, what statement would contain the most information in the fewest words?"

responses = {}
for model in models
    # construct a request that will be sent to the LLM
    request = glim.request(llm_name: model)
    request.prompt = question
    # LLMResponse.compute will send the request to the model specified in the request, but not wait for the result
    responses[model] = request.send_and_return_future
end

# now we can rate and summarize  the answers

# construct a request using an erb template. The template is in the specs directory
# and is called "rate_all.erb". We will pass the question and the hash with all of the
# answers to the template.
request = glim.request_from_template("rate_all", question:, answers: responses)

# the request now contains a prompt that is based on the template and the
# arguments that we passed to the template (question and answers)
puts request.inspect

# send the request and print the completion it generated
response = request.response
puts response.completion


