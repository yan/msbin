#!/usr/bin/env ruby

# by Yan Ivnitskiy
#   yan@matasano.com

require 'msbin/records'

def read_long(handle)
   return handle.read(4).unpack('L').first
end

def read_string(handle)
	len = read_int31(handle)
   str = handle.read(len)
	return str
end

def read_int8(handle)
	return handle.read(1)[0]
end

def read_int16(handle)
	return handle.read(2).unpack("s").first
end

# TODO: bundle these in a module
def read_int31(handle)
	val = 0
	pow = 1
	begin
		byte = read_int8(handle)
		val += pow * (byte & 0x7F)
		pow *= 2**7
	end while (byte & 0x80) == 0x80
	return val	
end

def read_int32(handle)
	return handle.read(4).unpack("L").first
end

def read_float(handle)
	return handle.read(4).unpack("g").first
end

def read_int64(handle)
	return handle.read(8).unpack("Q").first
end

def read_double(handle)
	return handle.read(8).unpack("E").first
end


def read_dictstring(handle)
	val = read_int31(handle)
	return MSBIN_DictionaryStrings[val]
end


module MSBIN
	class Record
		@@records = []
		attr_accessor :children

		class << self
			attr_accessor :record_type

			def inherited(klass)
				@@records << klass
			end
	
			# TODO: Document this
			def define_with_endelement
				record_type = self.record_type
				c = Class.new(self) do
					@record_type = record_type+1
					def is_endelement?
						return true
					end
				end

				name = self.name.split(':').last+"WithEndElement"
				MSBIN.const_set name, c
			end

			def is_attribute?(type)
				nil != @@records.find do |klass|
					klass.ancestors.include? Attribute and klass.record_type === type
				end
			end

			def record_type_to_class(record_type)
				@@records.find{|klass| klass.record_type === record_type}
			end
	
			def DecodeStream(handle)
				element_stack = []
				while !handle.eof()
					a = MakeRecord(handle)
					if not a.is_endelement?
						indent = 0
						element_stack.push a
					else
						ended = element_stack.pop
						puts "Adding #{a} to #{ended}"
						if not ended.children # this is hacky, default children to an empty arr
							ended.children = []
						end
						ended.children.push a

						if a.class.name =~ /WithEndElement$/
							element_stack.push ended
							puts "Again"
							ended = element_stack.pop
							if not element_stack.last.children
								element_stack.last.children = []
							end
							puts "Adding #{ended} to #{element_stack.last}"
							element_stack.last.children << ended
						end
						#element_stack.last.children << 
						indent = -1
					end
			
					#element_stack.push(a)
					write_xml a, indent
				end
			end
	
			def MakeRecord(handle)
				record_type = read_int8(handle)
				klass = self.record_type_to_class(record_type)
				if not klass
					raise "Unsupported type: 0x#{record_type.to_s(16)}"
				end
				#TODO: move the 2-arg initializer to the base class somehow
				ret = klass.new(handle, record_type)
	
				if ret.is_a? Element and ret.class.to_s !~ /EndElement$/
					$element_stack.push ret
				end
	
				ret
			end
		end
		
		def initialize(handle, record_type)
		end

		def get_attributes(handle)
			@attributes = []
			loop do
				where = handle.pos
				next_type = read_int8(handle)
				handle.seek(where)

				break if not Record.is_attribute? next_type
				@attributes << Record.MakeRecord(handle)
			end
		end
		def type_of?(type)
			raise NotImplementedError
		end
		def is_endelement?
			return self.instance_of?(EndElement)
		end
	end
end


