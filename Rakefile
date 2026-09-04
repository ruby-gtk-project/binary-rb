# frozen_string_literal: true

require 'rake/testtask'

Rake::TestTask.new(:test) do |t|
  t.libs << 'lib' << 'test'
  t.test_files = FileList['test/test_*.rb']
  t.warning = false
end

desc 'Drive the window headlessly and write screenshots to tmp/shots'
task :drive do
  sh 'ruby -Ilib -Itest test/drive_window.rb'
end

task default: :test
