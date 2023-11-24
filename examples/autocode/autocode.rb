require_relative '../../lib/glim_ai'

require 'tempfile'
require 'open3'

# An example of how one could use Glim to write code automatically
class CodeBase
    include AICallable
    def done?
        return @done != nil
    end

    def initialize(run_command:, project_root:)
        @run_command = run_command
        @project_root = project_root
        @done = nil
    end

    attr_reader :run_command
    attr_accessor :project_root

    def done_confidence
        return @done
    end

    ai_callable_as :show_file do
        describe "Returns the contents of the file with the given path name"
        string :path_name, "The path name of the file to show", required:true
    end
    def show_file(path_name:)
        puts "Reading file and providing to LLM: project_root = #{project_root}  /   #{path_name}"
        begin
            full_path = File.join(project_root, path_name)
            return File.read(full_path)
        rescue Errno::ENOENT
            return "File not found"
        rescue
            raise
        end
    end

    ai_callable_as :find do
        describe "Returns a directory listing, recursively, for the given path."
        string :path_name, "The path of the directory you want to see, relative to the project root", required:true
    end
    def find(path_name:)
        puts "Providing directory listing to LLM: project_root = #{project_root}  /   #{path_name}"
        begin
            s = `cd #{project_root}; find #{path_name}`
            return s
        rescue Errno::ENOENT
            return "File not found"
        rescue
            raise
        end
    end

    # ai_callable_as :run_code do
    #     describe "Run the code to try it out. Returns [stderr, stdout] with the output produced by running the code."
    #     number :confidence_level, "Your estimate of the likelihood (0..1) that your code changes will work.", required:true
    # end    

    # plan was to allow LLM to trigger this, but it turns out that's more complicated
    # because it doesn't reliably call a function AND provide a completion
    def run_code(confidence_level: 1)
        Open3.popen3(@run_command) do |stdin, stdout, stderr, thread|
            output, errors = "", ""
            out_thread = Thread.new { output = stdout.read }
            err_thread = Thread.new { errors = stderr.read }
            out_thread.join
            err_thread.join
            puts "\n\n\n>>> $#{@run_command}"
            return errors,output
        end
    end
    
    ai_callable_as :code_ran_as_expected do
        describe "Call this to indicate that the code ran as expected."
        number :confidence_level, "Your estimate of the likelihood (0..1) that the code ran as expected and accomplished the given task.", required:true
    end    
    def code_ran_as_expected(confidence_level:)
        puts "\n\n\nWe think we are done; code ran as expected. Confidence level: #{confidence_level}"
        @done = confidence_level
    end
end

def perform_task(llm_name:, project_root:, task:, run_command:)

    cb = CodeBase.new(run_command:, project_root:)
    glim = GlimContext.new(log_name:"autocode")
    req = glim.request_from_template("task", task:)
    req.llm_name = llm_name

    max_iter = 5

    for iter in 0..max_iter
        req.set_functions_object(cb)
        puts "Iteration #{iter}: #{req.prompt_token_count} + up to #{req.max_tokens}, cost so far: #{glim.total_cost}}"
        while (req.context_length - req.prompt_token_count) < (req.context_length * 0.2)
            # TODO
            # compress the message history in some clever way? 
            req.message_history.shift
            req.update_request_hash
            puts "Iteration #{iter}: Dropped a message, now #{req.prompt_token_count} + up to #{req.max_tokens}"
        end
        response = req.response
        completion = response.completion
        files_saved = []
        just_ran_code = false
        if completion
            puts "Got Completion: #{completion}"
            text, files_saved = response.extract_files_from_completion(cb.project_root)
            puts "Extracted #{files_saved.length} files from completion."
            if files_saved.length == 0 && (! response.function_call_message?)
                response.add_anomaly 0.2, "No files saved, no point in running the code."
            end
            puts "*******"
            puts completion
            if completion.include?("```")
                response.add_anomaly 0.9, "Response may contain code, but it's not in the right format."
                req = response.create_request_for_chat
                req.prompt = "It looks like you included a file, but in the wrong format. Remember to enclose files, like this <file>data</file>."    
            end
        end
        # either there was a completion and we handled it, or there was no completion.
        # regardless, we need to now see if there is a function to call.
        if response.function_call_message?
            if cb.done?
                if just_ran_code
                    break
                else
                    stderr, stdout = cb.run_code
                    just_ran_code = true
                    req = response.create_request_for_chat
                    req.process_template("changed_files_now_evaluate_output", stdout:, stderr:, files_saved:)
                    next
                end
            end
            new_req = response.create_request_with_function_result
            # that invoked the function requested, so now we can check:
            req = new_req
        elsif files_saved.any?
            # got some new files and no function eval request, might as well just run it. 
            stderr, stdout = cb.run_code
            just_ran_code = true
            # construct new request with the output of the code
            req = response.create_request_for_chat
            req.process_template("changed_files_now_evaluate_output", stdout:, stderr:, files_saved:)
            # function object will be set in next iter
            next
        elsif completion
            req = response.create_request_for_chat
            req.prompt = "You did not include a function_call or file. Please carefully check your instructions and try again."
        else
            response.add_anomaly(1.0, "not sure what to do - no function call and no completion (and of course no files saved)")
        end
    end
    puts "Done with #{iter} iterations. Total cost: #{glim.total_cost}"

end

# task = "Add a new function extract_fields to lib/globals.rb. It should in a similar way as extract_files in lib/globals.rb, "+
#     "but instead of only looking at <file ...> it looks extracts all text from all XML tags, and then returns a single hash. " +
#     "For example, if the input string contained <greet>Hello</greet>, it would return { greet: \"Hello\" }." +
#     "Avoid introducing dependencies on large libraries like nokogiri since the problem is fairly simple. " +
#     "Also add a unit test for this function, test/extract_fields_test.rb"
    
task = "Add more tests to test/extract_fields_test"
    #task = "Add some more sensible unit tests to the code base."
llm_name = "gpt-3.5-turbo"
#llm_name  = "gpt-4"
#llm_name = "claude-2"
project_root = "../autocode/"
run_command = "cd #{project_root}; ruby test/extract_fields_test.rb"

perform_task(llm_name:, project_root:, task:, run_command:)


