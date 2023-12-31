# What?

Glim is a ruby gem for using LLM Web APIs (OpenAI, Anthropic, etc) in real world, production applications.

It takes care of a bunch of annoying, tedious tasks so you don't have to:

```ruby
require 'glim_ai'
glim = GlimContext.new
r = glim.request(model_id: "gpt-3.5", prompt: "Hello World - Explain.").await_response
puts r.completion
# and you get lots of nice things, like this:
puts "Completion had #{r.completion_tokens} tokens, cost $#{r.total_cost}"  
```

# Why? 

There a literally dozens of libraries and thousands of blog posts showing how "easy" it is to build powerful applications that utilize LLM APIs.
Yes, it's easy if it only needs to work for the example in a blog post or demo video. But it's surprisingly difficult and tedious to build robust apps that work for a wider range of situations than cherry picked examples. 

The goal with glim is to change that. No magic here, just an attempt to take the wonkiness out of building AI based apps. 

Specifically, with Glim, you can
- manage your prompts separate from your code
- send requests asynchronously without having to think about managing concurrency any more than necessary
- keep your code as provider- and model-agnostic as possible; in most cases, there is no need to change your code if you want to use a different model. At the same time, you still have full access to API-specific features

There are a number of convenience features:
- Responses are cached, so that if your code had a bug and you run it again, it's faster and doesn't cost you anything
- Easy to determine token usage and keep track of cost
- Template language for prompts (erb)
- Tools for augmenting the prompt with files and data 
- Tools for extracting data from the response, even if not directly support by a model
- Convenient handling of OpenAI "functions" 
- Smart, efficient handling of rate limits 
- logging of requests and responses
- Tools for managing anomalies experienced at runtime, to support iterative improvement of prompts

# Programming paradigm / How do you use glim? 

The general idea is that you create a request and can modify it until you're happy with it. 
Then, you can send it off with request.send_and_return_future, and optionally pass a block to be run when the response has been received. 
You get a GlimResponseFuture back. On this you can call response, which will block until the result is there, and then return a GlimResponse. 
The GlimResponse object contains lots of convenience functions to extract data or files from the completion, handle function calling, etc. 

# Getting Started

Install the gem:

```
gem install glim_ai
cp sample.env .env
bin/setup
```

Add your API keys to your copy of .env.

With that, you're good to go, example code: 

```ruby
require 'glim_ai'
glim = GlimContext.new
req = glim.request(model_id: "gpt-3.5")
req.prompt = "Who came up with the phrase 'Hello World?'"
puts req.response.completion
puts "Cost = $ #{req.response.total_cost}"
```

More in examples/.

# Choosing the model to use

To see which models are available, run:
```
bundle exec glim_list_models
```
This shows the models currently available along with their cost and current speed (tokens per second).

For example:
```
gpt-4          =                                gpt-4-32k@openai    , context length:  16384, prompt: $ 60.00/Mt, completion: $120.00/Mt ERROR: the server responded with status 404
gpt-3.5        =                            gpt-3.5-turbo@openai    , context length:  16384, prompt: $  1.00/Mt, completion: $  2.00/Mt  40.4 tk/s -> gpt-3.5-turbo-0613
llama2-7       =            meta-llama/Llama-2-7b-chat-hf@anyscale  , context length:   4096, prompt: $  0.15/Mt, completion: $  0.15/Mt  54.0 tk/s
```
This tells you that in your code, you can do:
```
request.model_id = 'llama2-7"
```
You can manage the list yourself; but the idea is that we will try to keep it up to date - see GlimAI#set_model_repo(repo).

# Anomaly Management

If you parse the output generated by an LLM for further processing in your code, 
and there is a long tail of rare cases where the output is not in the format your code expects. 
For example, your prompt asks for a json response, but 0.1% of the time, you get the wrong json schema, or even something like "Here is your json file: "
Or in complex prompt chains or trees, your code might detect that a particular response wasn't useful.

All of this happens during runtime, and these situations aren't exactly errors, but they do require improving your code and/or your prompts. 
To manage this, Glim includes a mechanism for the code to annotate a response when it sees something abnormal.

```ruby
response.add_anomaly(0.5, "Received text instead of a number")
```

This is logged in the file system, and can then later be processed for the purpose of improving the prompt. 
For each response that has an anomaly, a new directory is created, which contains the prompt template, the prompt, the complete request hash, and the response from the API. 

The application code still needs to handle errors in whatever way makes sense; the idea is that the anomalies accumulate during runtime, and can be reviewed periodically to see if the prompt template needs to be improved. 

# License

The gem will be available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

# TODO

- rename response to await_response
- replace the ad hoc putt() with Logger
- store extracted fields in glim_log/...../
- store extracted files glim_log/...../
- make tests independent of models so that they don't fail just because you don't have access to a particular provider's models 
- factor out a notion of "extractors"; so that you can stub response or maybe get anomalies back as an array.. to make unit tests better
- write a better README

## Feature improvements - do these when needed

- make use of "length" field:
- prevent submitting requests that are likely to not fit in context, except for zephyr with its sliding window
- AICallable 
  more data types: array, boolean?
  allow changing the ai_name for the function, not just the args; GPT4 seems to look at the names more than the descriptions

## Examples

autocode example:
- GPT3.5 creates files in wrong format, and then it keeps trying.

## Closer to Application level

- Autocompress older part of chat conversation
- support "continue" prompting, especially for claude; 2k tokens is not much
  need to figure out if there is a way to get claude to plan its responses to make them longer?
  or is staying under the max tokens part of training? 

## More LLMs to support

- support replicate.com in addition to anyscale? 
- Azure

## Probably not worth doing

- Token healing? 
https://github.com/guidance-ai/guidance

# Internals

## Design Details

A GlimRequest represents a request to an LLM to perform a task. GlimRequest itself contains 
functionality and parameters that are common to all supported models:
- parameters like temperature, top_p, etc
- the name of the llm to be used
- code for handling erb templates
- token counting and cost estimate code

To support functionality that is specific to some LLM APIs, there is, for each supported LLM API, 
a GlimRequestDetails class that is instantiated dynamically based on llm_name and then any 
missing methods in GlimRequest are delegated to it. 

So each GlimRequest can have a reference to a GlimRequestDetails object, to which it delegates
methods it doesn't have. The GlimRequest, potentially with support from a GlimRequestDetails object, has to meet
one key responsibility: After it is created, it must at all times be able to provide a request_hash, 
which is a Hash that contains all of the data that needs to be sent to the LLM's API in order to
submit the request.

Thus, the GlimRequest and GlimRequestDetails must, whenever the user make a modification to either, 
update its internal request_hash to stay consistent. 

There is one tricky situation that is a bit annoying, but we decided to be pragmatic about it
and tolerate some awkwardness: If you change the llm for a GlimRequest to an llm that requires a different
GlimRequestDetails class, then the GlimRequestDetails will be replaced and any data in it is lost. 

For example, when changing from "gpt-3.5-turbo" (ChatRequestDetails) to "claude-instant-1" (AnthropicRequestDetails),
then the output_schema or function_object will of course be deleted. This is facilitated by the GlimRequest
creating a new AnthropicRequestDetails instance; as it is created, it is responsible for making sure that
the request_hash is accurate. In the other direction, changing from claude to GPT, similarly, a new
ChatRequestDetails instance would be created. 

Above we have described that (and how) a GlimRequest can always provide a request_hash object. 
This hash is used for generating the cache key. If the hashes are identical, we don't need
to contact the LLM API again, which saves time and money. The corresponding GlimResponse class can call GlimRequest#request_hash to obtain the necessary data, and then it is responsibe for sending the request off to an LLM, as well as interpreting the response
and making it accessible in a convenient way to the user. 

There is one additional feature that is related: For each GlimRequest, there is a log directory, in which
at any time there are several files that represent the content of the GlimRequest:
- generic_request_params: temperature, llm_name, etc 
- prompt 
- template_text (if a template was used)
- request_hash

And for ChatRequestDetails, also:
- messages: the array of messages, up to and including the message that will be sent
- output_schema.json

Once a response has been created, it would also contain:
- raw_response.json: the exact reponse as received when making the LLM API call
- completion.txt: just the completion that was generated by the LLM for this request
