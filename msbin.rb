#!/usr/bin/env ruby

# by Yan Ivnitskiy
#   yan@matasano.com

require 'msbin/types'

if ARGV.size == 0
	$stderr.write("Usage: #{$0} [file.msbin|-]\n")
	exit 1
end

f = ARGV[0] == '-' ? $stdin : File.new(ARGV[0], "rb")

# check if we have an http post, and consume headers
if f.read(4) == "HTTP"
	while f.readline().chomp != ""; end
else
	f.seek(0)
end

MSBIN::Record.DecodeStream(f)
