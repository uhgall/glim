# frozen_string_literal: true

require 'bundler/gem_tasks'
require 'rake/testtask'
require 'fileutils'

Rake::TestTask.new(:test) do |t|
  t.libs << 'test'
  t.libs << 'lib'
  t.test_files = FileList['test/**/*_test.rb']
end

task default: :test

task :clean do
  path = "tmp"
  dest_path = File.join("/tmp", "glim", "tmp_#{Time.now.to_i}")
  FileUtils.mkdir_p(dest_path) unless File.directory?(dest_path) # Ensure dest_path exists
  FileUtils.mv(path, dest_path)
  FileUtils.mkdir(path)
end

task :run_examples do
  # run each subdir in examples
  Dir.glob('examples/*').each do |dir|
    next unless File.directory?(dir)
      main_name = File.basename(dir)
      system "ruby #{dir}/#{main_name}.rb"
  end
end