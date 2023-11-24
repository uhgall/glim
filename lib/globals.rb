require 'thread'
require 'fileutils'

require 'active_support/core_ext/hash/indifferent_access'
require_relative 'glim_ai/version'

$putt_timestamp = Time.now

class RateLimitExceededError < RuntimeError; end
class LLMError < StandardError; end

class APILimiter
  def initialize(max_concurrent_requests:)
    @max_concurrent_requests = max_concurrent_requests
    @mutex = Mutex.new
    @condition = ConditionVariable.new
    @counter = 0
  end

  attr_reader :max_concurrent_requests

  def with_limit
    @mutex.synchronize do
      @condition.wait(@mutex) while @counter >= @max_concurrent_requests
      @counter += 1
    end
    begin
      yield # Execute the provided block
    rescue RateLimitExceededError => e
      retries += 1
      if retries <= @max_retries
        putt :rpc, "Rate limit exceeded. Retrying in #{2 ** retries} seconds."
        sleep(2 ** retries + rand) # Exponential backoff with some random jitter
        retry
      else
        raise "Max retries reached. Original error: #{e.message}"
      end
    ensure
      @mutex.synchronize do
        @counter -= 1
        @condition.signal
      end
    end
  end
end



# [{pathname: "f1", content: "hello"}, {pathname: "f2", content: "world"}]
def extract_files(input:, base_path_for_saving: nil, log_path_for_saving: nil)
  files = {}
  info_text = ""
  
  error("input is empty") if !input || input.empty?

  parts = input.split(/(<file pathname="[^"]+">|<\/file>)/)
  
  #putt :extract_files, "parts:\n #{JSON.pretty_generate(parts)}"

  in_file = false
  parts.each_with_index do |part, idx|
    if part =~ /<file pathname="([^"]+)">/
      pathname = $1.strip
      content = parts[idx + 1]
      files[pathname] = content.strip
      save_file(pathname, content, base_path_for_saving) if base_path_for_saving
      flat_pathname = pathname.gsub('/', '_')
      save_file(flat_pathname, content, log_path_for_saving) if log_path_for_saving
      in_file = true
      info_text += part # append the opening tag to info_text
    elsif part == "</file>"
      in_file = false # reset when encountering the closing tag
    else
      info_text += part unless in_file
    end
  end
  if files.empty?
    info_text = input
  end
  return info_text, files
end

# Another way to do it, if the above breaks
#
# require 'strscan'

# text = <<~XML
#   <file pathname="f1">hello</file>
#   <file pathname="f2">world</file>
# XML

# files = []

# scanner = StringScanner.new(text)

# while !scanner.eos?
#   if scanner.scan_until(/<file /)
#     path = scanner.scan(/"(.*?)"/)
#     scanner.scan_until(/>/)
#     content = scanner.scan_until(/<\/file>/)
#     files << {pathname: path, content: content}
#   end
# end 

# puts files

def save_files(files, base_paths)
  for file in files
    for base_path in base_paths
      save_file(file[:pathname], file[:content], base_path)
    end
  end
end

def save_file(filename, content, base_path)
  putt :file_helper, "Saving file #{filename} to #{base_path}, #{content.length} chars"
  relative_path = filename
  path = File.join(base_path, relative_path)  # Append relative_path under base_path
  directory = File.dirname(path)
  begin
    if path && (File.exist?(path) || Dir.exist?(path))
      timestamp = Time.now.strftime('%Y%m%d%H%M%S')
      #FileUtils.mv(path, "old-#{timestamp}-#{File.basename(path)}")
      FileUtils.mv(path, File.join(directory, "old-#{timestamp}-#{File.basename(path)}"))
    end
    FileUtils.mkdir_p(directory) unless Dir.exist?(directory)
    File.open(path, 'w') { |file| file.write(content) } unless content.to_s.empty?
  rescue StandardError => e
    puts "An error occurred while processing file at #{path}: #{e.message} - #{e.backtrace.join("\n")}"
  end
end


def levenshtein_distance(str1, str2)
  raise ArgumentError, "str1 must be a String" unless str1.is_a?(String)
  raise ArgumentError, "str2 must be a String" unless str2.is_a?(String)
  matrix = Array.new(str1.length + 1) { Array.new(str2.length + 1, 0) }
  edits = ""

  (1..str1.length).each { |i| matrix[i][0] = i }
  (1..str2.length).each { |j| matrix[0][j] = j }

  (1..str1.length).each do |i|
    (1..str2.length).each do |j|
      cost = str1[i - 1] == str2[j - 1] ? 0 : 1
      matrix[i][j] = [
        matrix[i - 1][j] + 1,
        matrix[i][j - 1] + 1,
        matrix[i - 1][j - 1] + cost
      ].min
    end
  end

  i, j = str1.length, str2.length
  while i > 0 && j > 0
    min_val = [matrix[i-1][j], matrix[i][j-1], matrix[i-1][j-1]].min
    if min_val == matrix[i-1][j-1]
      edits << (str1[i - 1] == str2[j - 1] ? "M" : "S")
      i -= 1
      j -= 1
    elsif min_val == matrix[i-1][j]
      edits << "D"
      i -= 1
    else
      edits << "I"
      j -= 1
    end
  end

  while i > 0
    edits << "D"
    i -= 1
  end

  while j > 0
    edits << "I"
    j -= 1
  end

  explanation = "#{str1}\n#{str2}\n#{edits.reverse}\n}"
  putt :levenshtein_distance, explanation
  [matrix[str1.length][str2.length], edits.reverse] #, explanation]
end


def putt(topic, s, options = [])
  options_putt = ENV.fetch('GLIM_OPTIONS_PUTT')
  return unless options_putt.include?(topic.to_s)
  #return unless [:log, :rpc, :cache].include?(topic)
  t = Time.now - $putt_timestamp
  line = "T+#{t.round(3)}sec:  " + "#{s}"
  puts(line) 
  if options.include?(:trace) || options_putt.include?("trace")
    for i in 1..([caller.length, 8].min)
      puts "\t"+caller[i]
    end
  end
end

require 'digest'

def deep_copy_with_mods(object, string_cutoff=80, array_cutoff=10)
  case object
  when Hash
    object.each_with_object({}) do |(key, value), result|
      result[key] = deep_copy_with_mods(value, string_cutoff, array_cutoff)
    end
  when Array
    if object.length > array_cutoff
      object[0...array_cutoff].map do |value|
        deep_copy_with_mods(value, string_cutoff, array_cutoff)
      end << ["... (#{object.length - array_cutoff} more)"]
    else
      object.dup
    end
  when String
    if object.length > string_cutoff
      truncated_string = object[0...string_cutoff]
      digest = Digest::SHA1.hexdigest(object)[0..7]
      "#{truncated_string}..#{digest} #{object.length}b}"
    else
      object
    end
  else
    object
  end
end


def extract_between_markers(str, start_marker, end_marker)
  str[/#{Regexp.escape(start_marker)}(.*?)#{Regexp.escape(end_marker)}/m, 1]
end

def extract_with_markers(str, start_marker, end_marker)
  str[/#{Regexp.escape(start_marker)}.*?#{Regexp.escape(end_marker)}/m]
end

# def extract_fields(input_string)
#   fields = {} 
#   input_string.scan(/<([^\/>]+)>([^<]*)<\/\1>/).each do |match|
#     fields[match[0].strip] = match[1].strip
#   end
#   fields
# end

def extract_fields(input_string)
  # Attempt to recursively extract fields to handle nested tags
  fields = input_string.scan(/<(\S+)[^>]*>(.*?)<\/\1>/m).to_h
  fields.each do |k, v|
    fields[k] = extract_fields(v) if v.include?('<')
  end
  fields
end


def extract_json(json_string)
  str = json_string.dup
  begin
    return JSON.parse(str)
  rescue JSON::ParserError => e
    putt :extract_json, "JSON parse error 1: #{e}"
  end
  str = extract_with_markers(str, "{","}")
  begin
    return JSON.parse(str)
  rescue JSON::ParserError => e
    putt :extract_json, "JSON parse error 2: #{e}"
  end
  str.gsub!(/,\s*}/, "}")
  return JSON.parse(str)
end

module Delegation
  def delegate(*methods, to:)
    methods.each do |method|
      define_method(method) do
        target = instance_variable_get("@#{to}")
        unless target
          raise "Delegation target @#{to} not set for method #{method}"
        end
        target.public_send(method)
      end
    end
  end
end
