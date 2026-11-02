# frozen_string_literal: true

# Runs the whole minitest suite in one process.
#
# `rake test` is the Rakefile's name for the same thing, but the wrapped
# binstub bundlerEnv builds cannot start at all (FINDINGS.md 10), so this is
# the form that works from the dev shell without a Rakefile in the way:
#
#   nix develop --command xvfb-run -a ruby test/run_tests.rb
#
# xvfb-run, because requiring the app requires gtk4, and gtk_init fails
# outright with no display on this machine (FINDINGS.md 11).

$LOAD_PATH.unshift(File.expand_path('../lib', __dir__))
$LOAD_PATH.unshift(__dir__)

Dir[File.expand_path('test_*.rb', __dir__)].sort.each { |file| require file }
