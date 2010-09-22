#!/usr/bin/env ruby

require 'records'
require 'types'

if ARGV.size == 0
	$stderr.write("Usage: #{$0} [file.msbin|-]\n")
	exit 1
end


def read_msbin(handle)
	while !handle.eof()
		a = MSBIN::Record.MakeRecord(handle)
		indent = a.class == MSBIN::EndElement ? -1 : 0
		write_xml a, indent

		if a.class.to_s =~ /WithEndElement$/# or ret.class == EndElement
			write_xml("</#{($element_stack.pop).name}>", -1)
		end
	end
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

MSBIN::Record.Decode(f)
#puts f
