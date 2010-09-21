#!/usr/bin/env ruby


def read_byte(handle)
   return handle.read(1)[0]
end

def read_int31(handle)
	val = byte = read_byte(handle)
	if byte & 0x7f
		return byte
	end

	byte = read_byte(handle)
	puts "#{val.to_s(16)} #{byte.to_s(16)}"

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

module MSBIN
	class Record
		@RECORDS = []
		
		def self.inherited(klass)
			@RECORDS << klass
		end

		def type_of?(type)
			raise NotImplementedError
		end

		def self.MakeRecord(handle)
			record_type = read_byte(handle)
			ret = nil
			@RECORDS.each do |klass|
				if klass.record_type === record_type
					#TODO: move the 2-arg initializer to the base class somehow
					ret = klass.new(handle, record_type)
				end
			end
			raise record_type.to_s(16) if not ret
			puts "Returning #{ret}"
			ret
		end
	end
end

module MSBIN
	class PrefixElement < Record
		def self.record_type
			return 0x5e .. 0x77
		end

		def initialize(handle, record_type)
			@name = read_string(handle)
			@record_type = record_type
			@attributes = Record.MakeRecord(handle)
		end

		def to_s
			"<#{(?a+@record_type-self.class.record_type.first).chr}:#{@name} #{@attributes}>"
		end
	end

	class PrefixDictionaryElement < Record
		attr :children

		def self.record_type
			0x44 .. 0x5D
		end
		
		def initialize(handle, record_type)
			@children = []
			@record_type = record_type

			# read name
			val = read_int31(handle)
			@name = "str#{val}" # handle.read(val)
			# TODO fill proper string names
			#puts "got name #{@name}"

			# read attributes
			@children = Record.MakeRecord(handle)
		end

		def to_s
			"<#{(?a+@record_type-self.class.record_type.first).chr}"
		end
	end

	class PrefixDictionaryAttribute < Record
		def self.record_type
			0x0c .. 0x25
		end

		def initialize(handle, record_type)
			val = read_int31(handle)
			@name = "str#{val}"
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
			@value = "str#{read_long(handle)}"
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
			@attributes = "str#{read_int31(handle)}"#Record.MakeRecord(handle)
		end

		def to_s
			" xmlns:#{@prefix}=\"#{@attributes}"
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
			@attribs = Record.MakeRecord(handle)
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
	end

	class OneText < Record
		def self.record_type; 0x82; end

		def initialize(handle, record_type)
			@text = "1"
		end
	end

	class OneTextWithEndElement < Record
		def self.record_type; 0x83; end

		def initialize(handle, record_type)
			@text = "1"
		end
	end

	# TODO: Parse this better
	class DateTimeTextWithEndElement < Record
		def self.record_type; 0x97; end

		def initialize(handle, record_type)
			@date_date = handle.read(8)
		end
	end

	class Chars8Text < Record
		def self.record_type; 0x98; end

		def initialize(handle, record_type)
			@length = handle.read(1)[0]
			@text = handle.read(@length)
		end
	end

	# TODO: Clean up the end element
	class Chars8TextWithEndElement < Record
		def self.record_type; 0x99; end

		def initialize(handle, record_type)
			@length = handle.read(1)[0]
			@text = handle.read(@length)
		end
	end

	class UniqueIdText < Record
		def self.record_type; 0xac; end

		def initialize(handle, record_type)
			@text = handle.read(16).unpack('H*')
			puts "Got UUID: #{@text}"
		end
	end

	# TODO: Separate this
	class UniqueIdText < Record
		def self.record_type; 0xad; end

		def initialize(handle, record_type)
			@text = handle.read(16).unpack('H*')
			puts "Got UUID: #{@text}"
		end
	end

	class EndElement < Record
		def self.record_type; 0x01; end

		def initialize(handle, record_type)
		end
	end

	class TrueTextWithEndElement < Record
		def self.record_type; 0x87; end

		#TODO: return true as value
		def initialize(handle, record_type)
			@value = "true"
		end
	end

	class Int8Text < Record
		def self.record_type; 0x88; end

		def initialize(handle, record_type)
			@value = handle.read(1)
		end
	end

	class Int8TextWithEndElement < Record
		def self.record_type; 0x89; end

		def initialize(handle, record_type)
			@value = handle.read(1)
		end
	end
end
