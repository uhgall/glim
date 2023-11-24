module GlimHelpers

    # TODO: modify this so that you can also include a single file, list of files, etc
    def include_files(path, prefix='')
        putt :include_files, "include_files(path: #{path}, prefix: #{prefix})"
        result = ""
        Dir.foreach(path) do |entry|
            next if entry.start_with?('.')
            entry_path = File.join(path, entry)
            relative_path = File.join(prefix, entry)
            if File.directory?(entry_path)
                result += include_files(entry_path, relative_path)
            else
                # elsif File.file?(entry_path)
                # result +=  "\n```\n# File: #{relative_path}\n"
                # result += File.read(entry_path)
                # result += "\n```\n"
                result += include_file(entry_path, relative_path)
            end
        end
        result
    end

    def include_file(entry_path, relative_path = nil)
        relative_path ||= entry_path
        raise("File not found: #{entry_path}") if !File.file?(entry_path)
        result = "\n<file pathname=\"#{relative_path}\">"
        result += File.read(entry_path)
        result + "</file>\n"
    end


    def prompt_output_files
<<-GLIM_PROMPT
I have upgraded your capabilities so that you can create files. 
To create a file called "hello.rb" in a directory called "greetings" that contains "# line 1\n# line 2\n", do this:
<file pathname="greetings/hello.rb">
# line 1
# line 2
</file>
If there is no reason to put a file into a subdirectory, then just specify the filename.
Be precise about the suffix of the file; some files just don't have a suffix.
Use this response format every time you are asked for one or more text files, not just for software code. 
GLIM_PROMPT
    end
    

    def prompt_output_files_code
<<-GLIM_PROMPT
I have upgraded your capabilities so that you can attach text files and source code files to your answer. 
To attach a file called "hello.rb" in a directory called "greetings" that contains "s = 'hello'\nputs s\n', you can write the following 4 lines:
<file pathname="greetings/hello.rb">
s = 'hello'
puts s
</file>

Use this capability any time you are asked to write software. Do not include source code in any other way; always use the <file> tag.
The file you specify will overwrite a file that's already there, so be sure to always repeat the full content of the file, 
don't just add sections to it. If there is no reason to put a file into a subdirectory, then just specify the filename.
GLIM_PROMPT
    end


end
    