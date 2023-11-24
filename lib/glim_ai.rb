require_relative 'glim_ai/version'

require 'dotenv'
Dotenv.load

require_relative 'glim_context'

require_relative 'glim_response'
require_relative 'glim_request'
require_relative 'glim_ai_callable'

require_relative 'chat_request_details'
require_relative 'chat_response'
require_relative 'anthropic_request_details'
require_relative 'anthropic_response'
require_relative 'glim_model'

require 'bundler'
PROJECT_HOME = Bundler.root.to_s

module GlimAI

  def self.model_repo
    @model_repo ||= default_model_repo
  end
  
  def self.model(model_id, provider = :default)
    m = self.model_repo.find(model_id, provider)
    raise "No model with id #{model_id} found for provider #{provider}" unless m
    return m
  end

  # the idea is that we would continuously update these. Maybe eventually even keep them in github somewhere, always maintained
  def set_model_repo(repo)
    @model_repo = repo
  end

  def self.default_model_repo

    models = {
      openai: {
        klass: ChatRequestDetails,
        url: "www.openai.com", # https://openai.com/pricing
        models: [
          ["gpt-4-1106-preview",                  10, 30, 128000, "gpt-4p"],
          ["gpt-4-1106-vision-preview",           10, 30, 128000, "gpt-4v"],
          ["gpt-4",                               30, 60, 8192, "gpt-4"],
          ["gpt-4-32k",                           60,120, 16384, "gpt-4"],
          ["gpt-3.5-turbo",                       1, 2, 16384, "gpt-3.5"],
        ],
      },
      anyscale: {
        klass: ChatRequestDetails,
        url: "www.anyscale.com",
        models: [
          ["meta-llama/Llama-2-7b-chat-hf",       0.15, 0.15, 4096,"llama2-7"],
          ["meta-llama/Llama-2-13b-chat-hf",      0.25, 0.25, 4096,"llama2-13"],
          ["meta-llama/Llama-2-70b-chat-hf",      1, 1, 4096,"llama2-70"],
          ["codellama/CodeLlama-34b-Instruct-hf", 1, 1, 4096,"codellama-34"],
          ["HuggingFaceH4/zephyr-7b-beta",        0.15, 0.15, 4096,"zephyr-7"], # double check context window size
          ["mistralai/Mistral-7B-Instruct-v0.1",  0.15, 0.15, 4096,"mistral-7"] # 4k sliding window
        ],
      },
      anthropic: {
        klass: AnthropicRequestDetails,
        url: "www.anthropic.com",
        models: [
          ["claude-instant-1",                    1.63, 5.51, 100_000, "claude-instant-1"],
          ["claude-2",                                 8, 24, 100_000, "claude-2"],
          ["claude-2.1",                             8, 24, 200_000, "claude-2.1"]
        ]
      }
    }
    m = ModelRepo.new
    m.add_models(models)
    return m
  end
end
