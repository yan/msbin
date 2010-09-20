#!/usr/bin/env ruby


def read_byte(handle)
   return handle.read(1)[0]
end

def read_int31(handle)
	val = first_byte = read_byte(handle)
	if (0x00 .. 0x7f) === first_byte
		return first_byte
	end

	raise "unsupported int"
	val <<= (second_byte = read_byte(handle))
	print val.to_s(16)
	#when 0x00 .. 0x7F: return first_byte
end

def read_long(handle)
   return handle.read(4).unpack('L').first
end

def read_string(handle)
   return handle.read(read_int31(handle))
end

$indent = " "
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
					ret = klass.new(handle)
				end
			end
			raise record_type.to_s(16) if not ret
			ret
		end
	end
end

module MSBIN
	class PrefixElement < Record
		def self.record_type
			return 0x5e .. 0x77
		end

		def initialize(handle)
			@name = read_string(handle)
			@attributes = Record.MakeRecord(handle)
		end
	end

	class PrefixDictionaryElement < Record
		attr :children

		def self.record_type
			0x44 .. 0x5D
		end
		
		def initialize(handle)
			@children = []

			# read name
			val = read_int31(handle)
			@name = "str#{val}" # handle.read(val)
			puts "got name #{@name}"

			# read attributes
			@children = Record.MakeRecord(handle)
		end
	end

	class PrefixDictionaryAttribute < Record
		def self.record_type
			0x0c .. 0x25
		end

		def initialize(handle)
			val = read_int31(handle)
			@name = "str#{val}"
		end
	end

	class DictionaryXmlnsAttribute < Record
		def self.record_type
			0x0B
		end
		
		def initialize(handle)
			@prefix = read_string(handle)
			@attributes = "str#{read_int31(handle)}"#Record.MakeRecord(handle)
		end
	end

	class ShortAttribute < Record
		def self.record_type; 0x04; end

		def initialize(handle)
			@name = read_string(handle)
			@value = Record.MakeRecord(handle)
		end
	end

	class ShortElement < Record
		def self.record_type; 0x40; end

		def initialize(handle)
			@name = read_string(handle)
			@attribs = Record.MakeRecord(handle)
		end
	end

	class TextRecord < Record
		def self.record_type; 0x00; end
	end

	class FalseTextWithEndElement < Record
		def self.record_type; 0x85; end

		def initialize(handle)
			@text = read_string(handle)
		end
	end
end
