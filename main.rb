#!/usr/bin/env ruby

require 'records'
require 'types'

if ARGV.size == 0
	$stderr.write("Usage: #{$0} file.msbin\n")
	exit 1
end


def read_msbin(handle)
	while !handle.eof()
		a = MSBIN::Record.MakeRecord(handle)
		indent = 0
		if a.class == MSBIN::EndElement
			indent = -1
		else
			indent = 1
		end
		write_xml a, indent

		if a.class.to_s =~ /WithEndElement$/# or ret.class == EndElement
			write_xml("</#{($element_stack.pop).name}>", -1)
		end
	end
end

f = File.new(ARGV[0], "rb")
read_msbin(f)
#puts f
