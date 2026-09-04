# frozen_string_literal: true

require 'rake/testtask'
require 'fileutils'

LOCALE_DIR = 'locale'
SCHEMA_DIR = 'data/schemas'

desc 'Compile po/*.po into locale/<lang>/LC_MESSAGES/binary.mo'
task :translations do
  File.readlines('po/LINGUAS', chomp: true).reject(&:empty?).each do |lang|
    File.join(LOCALE_DIR, lang, 'LC_MESSAGES').then do |dir|
      FileUtils.mkdir_p(dir)
      sh "msgfmt po/#{lang}.po -o #{dir}/binary.mo"
    end
  end
end

desc 'Compile the GSettings schema so the app can run from a checkout'
task :schemas do
  sh "glib-compile-schemas #{SCHEMA_DIR}"
end

desc 'Refresh po/binary.pot and merge it into every po/*.po'
task :pot do
  sh 'xgettext --from-code=UTF-8 --add-comments=Translators: ' \
     '--keyword=_ --keyword=n_:1,2 --keyword=c_:1c,2 --keyword=d_:2 ' \
     '--output=po/binary.pot --files-from=po/POTFILES'
  File.readlines('po/LINGUAS', chomp: true).reject(&:empty?).each do |lang|
    sh "msgmerge --update --backup=none po/#{lang}.po po/binary.pot"
  end
end

Rake::TestTask.new(:test) do |t|
  t.libs << 'lib' << 'test'
  t.test_files = FileList['test/test_*.rb']
  t.warning = false
end

desc 'Drive the window headlessly and write screenshots to tmp/shots'
task drive: %i[translations schemas] do
  sh 'ruby -Ilib -Itest test/drive_window.rb'
  sh 'ruby -Ilib -Itest test/drive_translated.rb'
end

desc 'Run rubocop, including the custom cops in cops/'
task :lint do
  sh 'rubocop'
end

task test: %i[translations schemas]
task default: %i[test lint]
