#!/usr/bin/env ruby

require 'msbin_types'

$indent = 0
def write_xml(s, increase=1)
	$indent += increase	
	if $indent < 0
		$indent = 0
	end
	indent = "  "*$indent
	#"(#{$indent} #{increase}) 
	puts "#{indent}#{s}"
end

def read_byte(handle)
   return handle.read(1)[0]
end

def read_int31(handle)
	val = byte = read_byte(handle)
	if byte & 0x7f
		return byte
	end

	byte = read_byte(handle)
	#puts "#{val.to_s(16)} #{byte.to_s(16)}"

	val <<= 8
	val  |= (byte = read_byte(handle))
	return val
end

def read_long(handle)
   return handle.read(4).unpack('L').first
end

def read_string(handle)
	len = read_int31(handle)
   str = handle.read(len)
	return str
end

$element_stack = []

module MSBIN
	class Record
		RECORDS = []
		
		def self.inherited(klass)
			Record::RECORDS << klass
		end

		def self.is_attribute?(type)
			nil != Record::RECORDS.select {|klass| klass.to_s =~ /Attribute$/}.find {|klass| klass.record_type === type}
		end

		def type_of?(type)
			raise NotImplementedError
		end

		def self.MakeRecord(handle)
			record_type = read_byte(handle)
			klass = Record::RECORDS.find{|klass| klass.record_type === record_type}
			#TODO: move the 2-arg initializer to the base class somehow
			ret = klass.new(handle, record_type)
			raise "Unsupported type: 0x#{record_type.to_s(16)}" if not ret

			if ret.class.to_s =~ /Element$/ and ret.class.to_s !~ /EndElement$/
				$element_stack.push ret
			end

			ret
		end
	end
end

module MSBIN
	class PrefixElement < Record
		def self.record_type
			return 0x5e .. 0x77
		end

		attr_accessor :name

		def initialize(handle, record_type)
			@name = "#{(record_type-self.class.record_type.first+?a).chr}:" + read_string(handle)
			@record_type = record_type
			@attributes = []

			loop do
				where = handle.pos
				next_type = read_byte(handle)
				handle.seek(where)

				break if not Record.is_attribute? next_type
				@attributes << Record.MakeRecord(handle)
			end

		end

		def to_s
			attribs = ""
			if @attributes
				attribs = " #{@attributes}"
			end
			"<#{@name}#{attribs}>"
		end
	end

	class PrefixDictionaryElement < Record
		attr_accessor :attributes

		def self.record_type
			0x44 .. 0x5D
		end
		
		def initialize(handle, record_type)
			@attributes = []
			@record_type = record_type

			# read name
			val = read_int31(handle)
			@name = "#{MSBIN_DictionaryStrings[val]}" # handle.read(val)
			# TODO fill proper string names
			#puts "got name #{@name}"

			loop do
				where = handle.pos
				next_type = read_byte(handle)
				handle.seek(where)

				break if not Record.is_attribute? next_type
				@attributes << Record.MakeRecord(handle)
			end
		end

		def name
			"#{(?a+@record_type-self.class.record_type.first).chr}:#{@name}"
		end

		def to_s
			attribs = ""
			if @attributes
				attribs = " #{@attributes}"
			end
			"<#{(?a+@record_type-self.class.record_type.first).chr}:#{@name}#{attribs}>"
		end
	end

	class PrefixDictionaryAttribute < Record
		def self.record_type
			0x0c .. 0x25
		end

		def initialize(handle, record_type)
			val = read_int31(handle)
			@name = "#{MSBIN_DictionaryStrings[val]}"
			@value = Record.MakeRecord(handle)
			@record_type = record_type
		end

		def to_s
			"#{@name}=\"#{@value}\""
		end
	end

	class ShortDictionaryXmlnsAttribute < Record
		def self.record_type; 0x0a; end

		# TODO Isolate classes that do DictionaryStrings
		# TODO: the value will be ' xmlns="@{value}"'
		def initialize(handle, record_type)
			@value = "#{MSBIN_DictionaryStrings[read_long(handle)]}"
		end

		def to_s
			" xmlns=\"#{@value}\""
		end
	end

	class DictionaryXmlnsAttribute < Record
		def self.record_type
			0x0B
		end
		
		def initialize(handle, record_type)
			@prefix = read_string(handle)
			@attributes = "#{MSBIN_DictionaryStrings[read_int31(handle)]}"#Record.MakeRecord(handle)
		end

		def to_s
			" xmlns:#{@prefix}=\"#{@attributes}\""
		end
	end

	class ShortXmlnsAttribute < Record
		def self.record_type; 0x08; end

		def initialize(handle, record_type)
			@value = read_string(handle)
		end

		def to_s
			" xmlns=\"#{@value}\""
		end
	end

	class XmlnsAttribute < Record
		def self.record_type; 0x09; end

		def initialize(handle, record_type)
			@prefix = read_string(handle)
			@value = read_string(handle)
		end

		def to_s
			" xmlns:#{@prefix}=\"#{@value}\""
		end
	end

	class ShortAttribute < Record
		def self.record_type; 0x04; end

		def initialize(handle, record_type)
			@name = read_string(handle)
			@value = Record.MakeRecord(handle)
		end

		def to_s
			" #{@name}=\"#{@vlaue}\""
		end
	end

	class ShortElement < Record
		def self.record_type; 0x40; end

		def initialize(handle, record_type)
			@name = read_string(handle)
			@attributes = []#Record.MakeRecord(handle)
			loop do
				where = handle.pos
				next_type = read_byte(handle)
				handle.seek(where)

				break if not Record.is_attribute? next_type
				@attributes << Record.MakeRecord(handle)
			end
		end

		def name
			@name
		end

		def to_s
			"<#{@name} #{@attributes}>"
		end
	end

	# Make this an ADT
	class TextRecord < Record
		def self.record_type; 0x00; end
	end


	# TODO: make this derive from TextRecord
	class FalseTextWithEndElement < Record
		def self.record_type; 0x85; end

		# TODO: Set a to_s to return false, that's it.
		def initialize(handle, record_type)
			#@text = read_string(handle)
		end

		def to_s; "false"; end
	end

	class OneText < Record
		def self.record_type; 0x82; end

		def initialize(handle, record_type)
			#@text = "1"
		end

		def to_s; "1"; end
	end

	class OneTextWithEndElement < Record
		def self.record_type; 0x83; end

		def initialize(handle, record_type)
			#@text = "1"
		end

		def to_s; "1"; end
	end

	# TODO: Parse this better
	class DateTimeTextWithEndElement < Record
		def self.record_type; 0x97; end

		def initialize(handle, record_type)
			# TODO: validate it
			@date_date 
			val = handle.read(8).unpack("Q")[0]
			@tz = val & 0xff
			val >>= 2

			# to microseconds
			val /= 10

			# to seconds
			val /= (10**6)

			# seconds since year 1 until epoch
			start = Time.utc(1, "jan", 1, 0, 0, 0, 0)
			epoch = Time.at(0)
			# seconds since 0
			val -= (epoch - start)

			# val is now epoch
			# not sure if this is correct, but it'll do for now
			@value = Time.at(val)
		end

		def to_s
			if @value.hour == 0 and @value.minutes == 0 and @value.seconds == 0
				return @value.strftime("%Y-%m-%d")
			else
				return @value.strftime("%Y-%m-%dT%H:%M:%S")
			end
		end
	end

	class Chars8Text < Record
		def self.record_type; 0x98; end

		def initialize(handle, record_type)
			@length = handle.read(1)[0]
			@text = handle.read(@length)
		end

		def to_s
			"#{@text}"
		end
	end

	# TODO: Clean up the end element
	class Chars8TextWithEndElement < Record
		def self.record_type; 0x99; end

		def initialize(handle, record_type)
			@length = handle.read(1)[0]
			@value = handle.read(@length)
		end

		def to_s
			"#{@value}"
		end
	end

	class UniqueIdText < Record
		def self.record_type; 0xac; end

		def initialize(handle, record_type)
			@text = handle.read(16).unpack('VvvC*')
		end

		def to_s
			return ("%08x-%04x-%04x-" % [@text[0], @text[1], @text[2]])+(("%02x"*6) % [@text[3..-1]])
		end
	end

	# TODO: Separate this
	class UniqueIdTextWithEndElement < Record
		def self.record_type; 0xad; end

		def initialize(handle, record_type)
			#@text = handle.read(16).unpack('H*')
			@text = handle.read(16).unpack('VvvC*')
		end
		def to_s
			return ("%08x-%04x-%04x-" % [@text[0], @text[1], @text[2]])+(("%02x"*6) % @text[3..-1])
		end
	end

	class EndElement < Record
		def self.record_type; 0x01; end

		def initialize(handle, record_type)
		end

		def to_s
			"</#{$element_stack.pop.name}>"
		end
	end

	class TrueTextWithEndElement < Record
		def self.record_type; 0x87; end

		#TODO: return true as value
		def initialize(handle, record_type)
			#@value = "true"
		end

		def to_s
			"true"
		end
	end

	class Int8Text < Record
		def self.record_type; 0x88; end

		def initialize(handle, record_type)
			@value = handle.read(1)
		end

		def to_s
			@value[0].to_s
		end
	end

	class Int8TextWithEndElement < Record
		def self.record_type; 0x89; end

		def initialize(handle, record_type)
			@value = handle.read(1)
		end

		def to_s
			@value[0].to_s
		end
	end
end
