#!/usr/bin/env ruby

require 'msbin_types'
require 'record'
require 'attributes'
require 'text'

$indent = -1
def write_xml(s, increase=1)
	indent = "  "*$indent
	puts "#{indent}#{s}"
	if s.class.to_s =~ /WithEndElement$/
		puts "#{indent}</#{$element_stack.pop.name}>"
		increase = -1
	end
	$indent += increase	
end


require 'iconv'
def from_unicode(str)
	return Iconv.conv('UTF-8', 'UTF-16LE', str)
end

$element_stack = []

module MSBIN
	class Reserved < Record
		@record_type = 0x00

		def initialize(handle, record_type)
			raise "Reserved type used"
		end
	end

	class Element < Record
	end

	class EndElement < Element
		@record_type = 0x01

		def to_s
			"</#{$element_stack.pop.name}>"
		end
	end

	class CommentElement < Element
		@record_type = 0x02

		def initialize(handle, record_type)
			@value = "<!--#{read_string(handle)}-->"
		end
	end

	# TODO: Implement Array
	class ArrayElement < Element
		@record_type = 0x03
		@records = {
			0xb5 => "Bool"
		}

		def initialize(handle, record_type)
			element = Record.MakeRecord(handle)
			raise "Array not implemented yet"
		end
	end

	class PrefixElement < Element
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

	class PrefixDictionaryElement < Element
		attr_accessor :attributes

		@record_type = 0x44 .. 0x5D
		
		def initialize(handle, record_type)
			$indent += 1
			@attributes = []
			@record_type = record_type

			# read name
			@name = read_dictstring(handle)
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

	class ShortElement < Element
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

	class DictionaryElement < Element
		@record_type = 0x43

		def initialize(handle, record_type)
			@prefix = read_string(handle)
			@name = read_dictstring(handle)

			get_attributes(handle)
		end

		def to_s
			attribs = @attributes ? " #{@attributes}" : ""
			"<#{@prefix}:#{@name}#{attribs}>"
		end
	end
end
