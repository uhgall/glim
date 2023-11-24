require_relative '../../lib/glim_ai'


# this written to figure out a good reliable prompt for generating multiple files
# it was before October 2023, so this might no longer be the best way to do this.
glim = GlimContext.new

testcases = [
    [ "gen_two_files", "Respond with two files named 'f1' and 'f2', which each contain the world `hello` and nothing else" ],
    [ "gen_word_list", "Respond with a file named `word_list` which contains the first 5 words from NATO phonetic alphabet, each in its own line." ],
    [ "write_code",  "Write a program in ruby called 'count_lines.rb' which reads a file and prints the number of lines in it. Include a test file with the numbers 1-5, one in each line, which should be called \"testfile.txt\"."],
    [ "gen_word_list_subdir", "Make a list of the first 5 words from NATO phonetic alphabet and put in your response a file with these words, each in its own line. The file should be named \"nato.txt\" and go into a subdirectory called 'fun_words'" ],
    [ "gen_n_files", "Respond with 8 files, name '1.nbr' ... '8.nbr', each containing the number of the file in it. For example, '1.nbr' should contain the number 1, '2.nbr' should contain the number 2, etc." ],
]

llm_names = ["gpt-3.5-turbo", "claude-instant-1"] + GlimRequest.llama2_llms
test_names = testcases.map { |x| x[0] }
try_names = []

responses = {}

Dir.glob(File.join(__dir__, "templates/try_*.erb")) do |try_path|
    try = File.basename(try_path,'.erb')   
    try_names << try 
    responses[try] = {} 
    for test_name, test_prompt in testcases
        responses[try][test_name] = {}
        for llm_name in llm_names        
            #puts "LLM = #{llm_name}, testing #{try} with prompt #{test_prompt}"
            req = glim.request_from_template(try, test_prompt: test_prompt)
            req.llm_name = llm_name
            req.temperature = 0.0
            req.log_name_this_request = "#{req.log_name_this_request}-#{test_name}-#{llm_name}" 
            responses[try][test_name][llm_name] = req.response
        end
    end
end

extracted_info = {}
for try in responses.keys
    extracted_info[try] = {}
    for test_name in responses[try].keys
        extracted_info[try][test_name] = {}
        baseline_extracted_info = nil
        baseline_completion = nil
        for llm_name in llm_names # we want them in this order because first one is the gold standard
            this_response = responses[try][test_name][llm_name]
            completion = this_response.completion
            extracted_by_llm = extract_files(completion)
            if !baseline_extracted_info
                baseline_extracted_info = extracted_by_llm
                baseline_completion = completion
                next
            end
            info = ""
            # if baseline_extracted_info[0] != extracted_by_llm[0]
            #     info += "\n\nExtracted info_text differs:\n#{extracted_info[0]}."
            #     info += "\nBaseline was:\n#{baseline_extracted_info[0]}."
            # end
            if baseline_extracted_info[1].keys != extracted_by_llm[1].keys
                files_llm = extracted_by_llm[1].keys
                files_baseline = baseline_extracted_info[1].keys
                if files_llm && !files_llm.empty?
                    info += "\nExtracted files:\n #{files_llm.join(',')}."
                else
                    info += "\nExtracted files: NONE."
                end
                info += "\nBaseline:\n #{files_baseline.join(',')}."
            end
            if !info.empty?
                puts "\n\n#{try} on test case #{test_name} with #{llm_name}:"
                puts info
                this_response.add_anomaly(0.5, info)
                #puts "\nCompletion was: \n#{completion}"
                extracted_info[try][test_name][llm_name] = info
            end
        end
    end
end

fail_info_for_try = {}
fail_analysis_for_try = {}

for try in try_names
    s = ""
    for test_name in test_names
        for llm_name in llm_names
            ei = extracted_info[try][test_name][llm_name] 
            if !ei || ei.empty?
                s += "\n<success test_name=#{test_name} llm_name=#{llm_name}></success>"
                puts "SUCCESS: #{try} on test case #{test_name} with #{llm_name}"
            else
                s += "\n<fail test_name=#{test_name} llm_name=#{llm_name}>"
                s += "\n#{ei}"
                s += "\n<original_prompt>"
                s += "\n#{responses[try][test_name][llm_name].full_prompt_as_text}"
                s += "\n</original_prompt>"
                s += "\n</fail>"
                puts "FAIL: #{try} on test case #{test_name} with #{llm_name}: #{extracted_info[try][test_name][llm_name]}"
            end
        end
    end
    fail_info_for_try[try] = s
    fail_analysis_for_try[try] = glim.request_from_template("fail_analysis", try:, fail_info: s)

end


for try in try_names
    puts "**** Results for #{try} ****"
    fail_analysis_response = fail_analysis_for_try[try].response
    puts "\n\n#{fail_analysis_response.completion}\n"
    #puts fail_info_for_try[try]
end