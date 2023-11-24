require_relative '../../lib/glim_ai'

llm_names =  ["claude-instant-1", "claude-2", "gpt-3.5-turbo-16k", "gpt-4" ]

glim = GlimContext.new

code = {} # lang,llm_name -> code
for lang in ["ruby", "python"] #, "javascript"]
    for llm_name in llm_names
        req = glim.request_from_template("write_code", language: lang)
        req.llm_name = llm_name
        code[[lang,llm_name]] = req.response 
        template_text = req.template_text
    end
end

out_path = "examples/code_competition/output"

for lang, llm_name in code.keys
    code[[lang,llm_name]] = code[[lang,llm_name]].completion
    File.write("#{out_path}/#{lang}_#{llm_name}.rb", code[[lang,llm_name]])
end

code[["ruby","human"]] = File.read("#{out_path}/ruby_human.rb")
ratings = {}

for llm_name in llm_names
    puts "analyze_code: #{llm_name}"
    request = glim.request_from_template("analyze_code", code:, text: template_text)
    request.llm_name = llm_name
    ratings[llm_name] = request.response
end

# TODO - would need to support arrays as args, first. 

# class CodeRatings
# include AICallable

# def initialize(developer_name)
#     @developer_name = developer_name
# end

# ai_callable_as :add_ratings do
#     describe "Report ratings extracted from the text"
#     string :lang, "The language of the code", required: true
#     number :elegance, "The elegance of the code", required: true
#     number :parallelism, "The parallelism of the code", required: true
#     number :correctness, "The correctness of the code", required: true
#     number :instructions_conformity, "The instructions conformity of the code", required: true
# end
# def add_ratings(**args)


response_by_llm_name = {}
for llm_name in llm_names
    req = glim.request(llm_name: "gpt-3.5-turbo")
    req.set_output_schema({
        type: "object",
        properties: {
            lang: { type: "string" },
            llm_name:  { type: "string" },
            elegance: {type: "number"},
            parallelism: {type: "number"},
            correctness: {type: "number"},
            instructions_conformity: {type: "number"}
        }   
    }, :list)
    text = ratings[llm_name].completion
    req.prompt = "Extract all of the json data from the following text:\n\n#{text}" 
    response_by_llm_name[llm_name] = req.response
end

ratings_by_llm_name = {}
for llm_name in llm_names
    ratings_by_llm_name[llm_name] = response_by_llm_name[llm_name].extracted_data
end

puts JSON.pretty_generate(ratings_by_llm_name)

# TODO -- analyze results