

class GlimModel < OpenStruct
  # attr_accessor :cost_per_prompt_token ,:cost_per_completion_token
  # attr_accessor :context_length
  # attr_accessor :llm_name
  # attr_accessor :provider
  def provider
    self[:provider].to_s
  end

  def to_s
    "#{model_id} = #{llm_name}@#{provider}"
  end

  def to_desc
    c_prompt = cost_per_prompt_token * 1000000
    c_completion = cost_per_completion_token * 1000000
    "#{model_id.ljust(14)} = #{llm_name.rjust(40)}@#{provider.ljust(10)}"+
    ", context length: #{'%6d' % context_length}, prompt: $#{'%6.2f' % c_prompt}/Mt, completion: $#{'%6.2f' % c_completion}/Mt"
  end


end


class ModelRepo
  
  def initialize(hash = {})
    @glim_models = hash.with_indifferent_access # model_id -> (provider -> glim_model)
  end

  attr_reader :glim_models

  def add_model(glim_model)
    model_id = glim_model.model_id
    @glim_models[model_id] ||= {}
    @glim_models[model_id][glim_model[:provider]] = glim_model
  end

  def add_models(models)
    models.each_pair do |provider, provider_data |
      provider_data[:models].each do |llm_name, cost_per_M_prompt_token, cost_per_M_completion_token, context_length, model_id|
        add_model(GlimModel.new(
          llm_name:, 
          cost_per_prompt_token: cost_per_M_prompt_token / 1000000.0 ,
          cost_per_completion_token: cost_per_M_completion_token / 1000000.0,
          context_length: ,
          model_id: ,
          provider: ,
          klass: provider_data[:klass],
          url: provider_data[:url]
        ))
      end
    end
  end

  def find(model_id, provider = :default)
    raise "No model_id #{model_id}" unless @glim_models[model_id]
    if provider == :default
      return @glim_models[model_id].values[0]
    else
      @glim_models[model_id][provider]
    end
  end

end

