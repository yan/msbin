#!/usr/bin/env ruby

require 'msbin/record'

# by Yan Ivnitskiy
#   yan@matasano.com

module MSBIN
	class ShortAttribute < Record
		@record_type = 0x04

		define_with_endelement

		def initialize(handle, record_type)
			@name = read_string(handle)
			@value = Record.MakeRecord(handle)
		end

		def to_s
			" #{@name}=\"#{@value}\""
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

	class ShortDictionaryAttribute < Attribute
		@record_type = 0x06

		def initialize(handle, record_type)
			@name = read_dictstring(handle)
			@value = Record.MakeRecord(handle)
		end

		def to_s
			" #{@name}=#{@value}"
		end
	end

	class DictionaryAttribute < Attribute
		@record_type = 0x07

		# TODO: Create a read_* method for dictionary strings
		# TODO: finalize the read_int31 function
		def initialize(handle, record_type)
			@prefix = read_string(handle)
			@name = read_dictstring(handle)
			@value = Record.MakeRecord(handle)
		end

		def to_s
			" #{@prefix}:#{@name}=\"#{@value}\""
		end
	end

	class PrefixAttribute < Attribute
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

	class PrefixDictionaryAttribute < Attribute
		@record_type = 0x0c .. 0x25

		def initialize(handle, record_type)
			@name = read_dictstring(handle)
			@value = Record.MakeRecord(handle)
			@record_type = record_type
		end

		def to_s
			"#{@name}=\"#{@value}\""
		end
	end

	class ShortDictionaryXmlnsAttribute < Attribute
		@record_type = 0x0a

		# TODO Isolate classes that do DictionaryStrings
		# TODO: the value will be ' xmlns="@{value}"'
		def initialize(handle, record_type)
			@value = read_dictstring(handle)
		end

		def to_s
			" xmlns=\"#{@value}\""
		end
	end

	class DictionaryXmlnsAttribute < Attribute
		@record_type = 0X0b
		
		def initialize(handle, record_type)
			@prefix = read_string(handle)
			@attributes = read_dictstring(handle)
		end

		def to_s
			" xmlns:#{@prefix}=\"#{@attributes}\""
		end
	end

	class ShortXmlnsAttribute < Attribute
		@record_type = 0x08

		def initialize(handle, record_type)
			@value = read_string(handle)
		end

		def to_s
			" xmlns=\"#{@value}\""
		end
	end

	class XmlnsAttribute < Attribute
		@record_type = 0x09

		def initialize(handle, record_type)
			@prefix = read_string(handle)
			@value = read_string(handle)
		end

		def to_s
			" xmlns:#{@prefix}=\"#{@value}\""
		end
	end


end
