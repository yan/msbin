#!/usr/bin/env ruby

require 'records'
require 'types'

if ARGV.size == 0
	$stderr.write("Usage: #{$0} file.msbin\n")
	exit 1
end

# def read_byte(handle)
# 	return handle.read(1)[0]
# end
# 
# def read_long(handle)
# 	return handle.read(4).unpack('L')
# end
# 
# def read_string(handle)
# 	return handle.read(read_long(handle))
# end
# 
# def read_record(handle)
# 	record_type = read_byte(handle)
# 	
# 	print "record type: #{Records[record_type]}"
# end

def read_msbin(handle)
	while !handle.eof()
		MSBIN::Record.MakeRecord(handle)
	end
end

f = File.new(ARGV[0], "rb")
read_msbin(f)
#puts f
