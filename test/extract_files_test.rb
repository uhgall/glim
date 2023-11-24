require 'minitest/autorun'
require 'fileutils'

require_relative "test_helper"

# require_relative '../lib/glim_helpers'
# require_relative '../lib/globals'

class ExtractFilesTest < Minitest::Test

  include GlimHelpers

  def setup
    @base_path = '/tmp/test_dir'
    FileUtils.mkdir_p(@base_path)
  end

  def teardown
    FileUtils.rm_rf(@base_path)
  end

  def test_extract_multiple_files_and_subdirectories
    
    # Define the text input that includes file content
    sample_text = <<~TEXT
Hello.
Now comes a file
<file pathname="file1.txt">
content of file1
</file>
So that was a file.

Here is one more:

<file pathname="subdir/file2.txt">
content of file2
etc
</file>
And now we are done.
TEXT
  
    # Define the expected output after file extraction
    expected_text = <<~TEXT
Hello.
Now comes a file
<file pathname="file1.txt">
So that was a file.

Here is one more:

<file pathname="subdir/file2.txt">
And now we are done.
TEXT

    # Check if the information is extracted correctly
    text, files_extracted = extract_files(input: sample_text)
    assert_equal "content of file1", files_extracted['file1.txt']
    assert_equal "content of file2\netc", files_extracted['subdir/file2.txt']
    assert_equal expected_text, text

    # Check if files are saved correctly
    log_path = File.join(@base_path, 'log')
    text, files = extract_files(input: sample_text, base_path_for_saving: @base_path, log_path_for_saving: log_path)
    assert_equal "\ncontent of file1\n",      File.read(File.join(@base_path, 'file1.txt'))
    assert_equal "\ncontent of file2\netc\n", File.read(File.join(@base_path, 'subdir', 'file2.txt'))

    assert_equal 2, files.length
    assert text.include?('Now comes a file')

    s = include_files(@base_path, prefix='')
    assert s.include?('file1')
  end

end
