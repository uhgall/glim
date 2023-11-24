require 'minitest/autorun'
require 'prettyprint'

require_relative '../lib/glim_ai'

ENV['GLIM_TEST_CACHE_DIRECTORY'] = 'tmp/test_cache'

# move the cache dir to /tmp and create it again
def clear_cache
    path = ENV['GLIM_TEST_CACHE_DIRECTORY']
    dest_path = File.join("/tmp", "glim", "glim_test_cache_#{Time.now.to_i}")
    puts("TestHelper moving cache from #{path} to #{dest_path}")
    FileUtils.mkdir_p(dest_path) unless File.directory?(dest_path) # Ensure dest_path exists
    begin
        FileUtils.mv(path, dest_path)
    rescue Errno::ENOENT 
        # ignore
    end
    FileUtils.mkdir(path)
end

clear_cache