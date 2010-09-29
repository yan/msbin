#!/usr/bin/env ruby

require 'records'
require 'types'

if ARGV.size == 0
	$stderr.write("Usage: #{$0} [file.msbin|-]\n")
	exit 1
end

if ARGV[0] == '-'
	f = $stdin
else
	f = File.new(ARGV[0], "rb")
end

# check if we have an http post, and consume headers
if f.read(4) == "HTTP"
	while f.readline().chomp != ""; end
else
	f.seek(0)
end

MSBIN::Record.DecodeStream(f)
#puts f
