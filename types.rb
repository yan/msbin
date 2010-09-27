#!/usr/bin/env ruby

require 'msbin_types'

#TODO: Separate attributes, text records, etc into separate files and modules

$indent = -1
def write_xml(s, increase=1)
	indent = "  "*$indent
	puts "#{indent}#{s}"
	$indent += increase	
end

def read_byte(handle)
   return handle.read(1)[0]
end

# TODO: bundle these in a module
def read_int31(handle)
	val = 0
	pow = 1
	begin
		byte = read_byte(handle)
		val += pow * (byte & 0x7F)
		pow *= 2**7
	end while (byte & 0x80) == 0x80
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
		@@records = []

		class << self
			attr_accessor :record_type

			def inherited(klass)
				@@records << klass
			end
	
			def is_attribute?(type)
				nil != @@records.select {|klass| klass.to_s =~ /Attribute$/}.find {|klass| klass.record_type === type}
			end
	
			def Decode(handle)
				while !handle.eof()
					a = MakeRecord(handle)
					indent = a.class == EndElement ? -1 : 0
					write_xml a, indent
			
					if a.class.to_s =~ /WithEndElement$/# or ret.class == EndElement
						write_xml("</#{($element_stack.pop).name}>", -1)
					end
				end
			end
	
			def MakeRecord(handle)
				record_type = read_byte(handle)
				klass = @@records.find{|klass| klass.record_type === record_type}
				raise "Unsupported type: 0x#{record_type.to_s(16)}" if not klass
				#TODO: move the 2-arg initializer to the base class somehow
				ret = klass.new(handle, record_type)
	
				if ret.class.to_s =~ /Element$/ and ret.class.to_s !~ /EndElement$/
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
				next_type = read_byte(handle)
				handle.seek(where)

				break if not Record.is_attribute? next_type
				@attributes << Record.MakeRecord(handle)
			end
		end

		def type_of?(type)
			raise NotImplementedError
		end
	end
end

module MSBIN
	class Reserved < Record
		@record_type = 0x00

		def initialize(handle, record_type)
			raise "Reserved type used"
		end
	end

	class EndElement < Record
		@record_type = 0x01

		def to_s
			"</#{$element_stack.pop.name}>"
		end
	end

	class CommentElement < Record
		@record_type = 0x02

		def initialize(handle, record_type)
			@value = "<!--#{read_string(handle)}-->"
		end
	end

	# TODO: Implement Array
	class ArrayElement < Record
		@record_type = 0x03

		def initialize(handle, record_type)
			raise "Array not implemented yet"
		end
	end

	class ShortAttribute < Record
		@record_type = 0x04

		def initialize(handle, record_type)
			@name = read_string(handle)
			@value = Record.MakeRecord(handle)
		end

		def to_s
			" #{@name}=\"#{@vlaue}\""
		end
	end

	# TODO: Make other attributes inherit from this to make this make more sense
	# TODO: Group them in a module and not have it all be flat
	class Attribute < Record
		@record_type = 0x05

		def initialize(handle, record_type)
			@prefix = read_string(handle)
			@name = read_string(handle)
			@value = Record.MakeRecord(handle)
		end

		def to_s
			" #{@prefix}:#{@name}=\"#{@value}\""
		end
	end

	class ShortDictionaryAttribute < Record
		@record_type = 0x06

		def initialize(handle, record_type)
			val = read_int31(handle)
			@name = "#{MSBIN_DictionaryStrings[val]}" # handle.read(val)
			@value = Record.MakeRecord(handle)
		end

		def to_s
			" #{@name}=#{@value}"
		end
	end

	class DictionaryAttribute < Record
		@record_type = 0x07

		# TODO: Create a read_* method for dictionary strings
		# TODO: finalize the read_int31 function
		def initialize(handle, record_type)
			@prefix = read_string(handle)
			@name = "#{MSBIN_DictionaryStrings[read_int31(handle)]}"
			@value = Record.MakeRecord(handle)
		end

		def to_s
			" #{@prefix}:#{@name}=\"#{@value}\""
		end
	end

	class PrefixElement < Record
		@record_type = 0x5e .. 0x77

		attr_accessor :name

		def initialize(handle, record_type)
			$indent += 1
			@name = "#{(record_type-self.class.record_type.first+?a).chr}:" + read_string(handle)
			@record_type = record_type
			@attributes = []

			get_attributes(handle)
		end

		def to_s
			attribs = @attributes ? " #{@attributes}" : ""
			"<#{@name}#{attribs}>"
		end
	end

	class PrefixAttribute < Record
		@record_type = 0x26 .. 0x3f

		def initialize(handle, record_type)
			@name = "#{(record_type-self.class.record_type.first+?a).chr}:" + read_string(handle)
			@record_type = record_type
			@value = Record.MakeRecord(handle)
		end

		def to_s
			" #{@name}=\"#{@value}\""
		end
	end

	class PrefixDictionaryElement < Record
		attr_accessor :attributes

		@record_type = 0x44 .. 0x5D
		
		def initialize(handle, record_type)
			$indent += 1
			@attributes = []
			@record_type = record_type

			# read name
			val = read_int31(handle)
			@name = "#{MSBIN_DictionaryStrings[val]}" # handle.read(val)
			# TODO fill proper string names
			#puts "got name #{@name}"

			get_attributes(handle)
		end

		def name
			"#{(?a+@record_type-self.class.record_type.first).chr}:#{@name}"
		end

		def to_s
			attribs = @attributes ? " #{@attributes}" : ""
			"<#{(?a+@record_type-self.class.record_type.first).chr}:#{@name}#{attribs}>"
		end
	end

	class PrefixDictionaryAttribute < Record
		@record_type = 0x0c .. 0x25

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
		@record_type = 0x0a

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
		@record_type = 0X0b
		
		def initialize(handle, record_type)
			@prefix = read_string(handle)
			@attributes = "#{MSBIN_DictionaryStrings[read_int31(handle)]}"#Record.MakeRecord(handle)
		end

		def to_s
			" xmlns:#{@prefix}=\"#{@attributes}\""
		end
	end

	class ShortXmlnsAttribute < Record
		@record_type = 0x08

		def initialize(handle, record_type)
			@value = read_string(handle)
		end

		def to_s
			" xmlns=\"#{@value}\""
		end
	end

	class XmlnsAttribute < Record
		@record_type = 0x09

		def initialize(handle, record_type)
			@prefix = read_string(handle)
			@value = read_string(handle)
		end

		def to_s
			" xmlns:#{@prefix}=\"#{@value}\""
		end
	end

	class ShortElement < Record
		@record_type = 0x40

		def initialize(handle, record_type)
			$indent += 1
			@name = read_string(handle)
			get_attributes(handle)
		end

		def name
			@name
		end

		def to_s
			attribs = @attributes ? " #{@attributes}" : ""
			"<#{@name}#{attribs}>"
		end
	end

	# Make this an ADT
	class TextRecord < Record
		@record_type = 0x00
		def initialize(handle, record_type)
			@record_type = record_type
		end
		def to_s
			@value.to_s
		end
	end

	class ZeroText < TextRecord
		@record_type = 0x80
		def to_s; "0"; end
	end
		

	class TrueText < TextRecord
		@record_type = 0x86
		def to_s; "true"; end
	end

	class TrueTextWithEndElement < TrueText
		@record_type = 0x87
	end

	# TODO: make this derive from TextRecord
	class FalseText < TextRecord
		@record_type = 0x84
		def to_s; "false"; end
	end
	
	class FalseTextWithEndElement < FalseText
		@record_type = 0x85
	end

	class OneText < TextRecord
		@record_type = 0x82
		def to_s; "1"; end
	end

	class OneTextWithEndElement < OneText
		@record_type = 0x83
	end

	# TODO: Parse this better
	class DateTimeText < TextRecord
		@record_type = 0x96

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
			time = Time.at(val)
			if time.hour == 0 and time.minutes == 0 and time.seconds == 0
				@value = time.strftime("%Y-%m-%d")
			else
				@value = time.strftime("%Y-%m-%dT%H:%M:%S")
			end
		end
	end

	class DateTimeTextWithEndElement < DateTimeText
		@record_type = 0x97
	end

	class DictionaryText < TextRecord
		@record_type = 0xaa

		def initialize(handle, record_type)
			val = read_int31(handle)
			@value = MSBIN_DictionaryStrings[val]
		end
	end

	class DictionaryTextWithEndElement < DictionaryText
		@record_type = 0xab
	end

	class Chars8Text < Record
		@record_type = 0x98

		def initialize(handle, record_type)
			require 'cgi'
			length = handle.read(1)[0]
			@value = CGI.escapeHTML(handle.read(length)).to_s
		end
	end

	# TODO: Clean up the end element
	class Chars8TextWithEndElement < Chars8Text
		@record_type = 0x99
	end

	class Chars16Text < Record
		@record_type = 0x9a

		def initialize(handle, record_type)
			require 'cgi'
			length = handle.read(2).unpack("n")[0]
			@value = CGI.escapeHTML(handle.read(length)).to_s
		end
	end

	# TODO: Clean up the end element
	class Chars16TextWithEndElement < Chars16Text
		@record_type = 0x9b
	end

	class UniqueIdText < Record
		@record_type = 0xac

		def initialize(handle, record_type)
			@uuid = handle.read(16).unpack('VvvC*')
			@value = ("%08x-%04x-%04x-" % [@uuid[0], @uuid[1], @uuid[2]])+(("%02x"*6) % @uuid[3..-1])
		end
	end

	# TODO: Separate this
	class UniqueIdTextWithEndElement < UniqueIdText
		@record_type = 0xad
	end

	class Int8Text < TextRecord
		@record_type = 0x88

		def initialize(handle, record_type)
			@value = handle.read(1)[0].to_s
		end
	end

	class Int8TextWithEndElement < Int8Text
		@record_type = 0x89
	end

	class Int16Text < TextRecord
		@record_type = 0x8a

		def initialize(handle, record_type)
			@value = handle.read(2).unpack("n")[0].to_s
		end
	end

	class Int16TextWithEndElement < Int16Text
		@record_type = 0x8b
	end

	class Int32Text < TextRecord
		@record_type = 0x8c

		def initialize(handle, record_type)
			@value = handle.read(4).unpack("l")[0].to_s
		end
	end

	class Int32TextWithEndElement < Int32Text
		@record_type = 0x8d
	end

	class Int64Text < TextRecord
		@record_type = 0x8e

		def initialize(handle, record_type)
			@value = handle.read(8).unpack("q")[0].to_s
		end
	end

	class Int64TextWithEndElement < Int64Text
		@record_type = 0x8f
	end

	class FloatText < TextRecord
		@record_type = 0x90

		def initialize(handle, record_type)
			@value = handle.read(4).unpack("g")[0].to_s
		end
	end

	class FloatTextWithEndRecord < FloatText
		@record_type = 0x91
	end

	class DoubleText < TextRecord
		@record_type = 0x92

		def initialize(handle, record_type)
			@value = handle.read(8).unpack("E")[0].to_s
		end
	end

	class DoubleTextWithEndElement < DoubleText
		@record_type = 0x93
	end

	class DecimalText < TextRecord
		@record_type = 0x94

		# TODO: Implement DecimalText
		def initialize(handle, record_type)
			raise "Not implemented"
		end
	end

	class DecimalTextWithEndRecord < DecimalText
		@record_type = 0x95
	end
end
