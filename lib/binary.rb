# frozen_string_literal: true

# The gem's require entry point, named after the gem: `require "binary"` loads
# the application `exe/binary` runs and nothing else.
#
# This file used to require a second application class of its own —
# `Binary::Application`, app id `org.rubygtkproject.Binary`, one window and a
# status page reading "The Ruby port has not been written yet." — while the
# real port was written in lib/main.rb. It has been deleted; the entry point
# points at the port.
require_relative 'main'
