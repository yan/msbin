#!/usr/bin/env ruby

# by Yan Ivnitskiy
#   yan@matasano.com

require 'msbin/msbin_types'
require 'msbin/record'
require 'msbin/attributes'
require 'msbin/text'

$indent = -1
def write_xml(s, increase=1, no_indent=false)
	indent = "  "*$indent if $indent >= 0
	indent = "" if no_indent
	print "#{indent}#{s}\n"
	if s.class.to_s =~ /WithEndElement$/
		print "#{indent}</#{$element_stack.pop.name}>\n"
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
			if !$element_stack.empty?
				"</#{$element_stack.pop.name}>"
			else
				""
			end
		end
	end

	class CommentElement < Element
		@record_type = 0x02

		def initialize(handle, record_type)
			@value = "<!--#{read_string(handle)}-->"
		end
	end

	# TODO: Implement Array
	# Array is extremely hacky since it writes to output directly
	class ArrayElement < Element
		@record_type = 0x03

		def initialize(handle, record_type)
			# reset element stack
			element = Record.MakeRecord(handle);
			$element_stack.pop
			endelement = Record.MakeRecord(handle)

			type = read_int8(handle)
			length = read_int31(handle)

			cls = Record.record_type_to_class(type)
			length.times do |idx|
				$element_stack.push element
				write_xml(element, 1)
				write_xml(cls.new(handle, type), -1)#, no_indent=true)
			end
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
			attribs = @attributes.empty? ? "" : " #{@attributes}"
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
			attribs = @attributes.empty? ? "" : " #{@attributes}"
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
			attribs = @attributes.empty? ? "" : " #{@attributes}"
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
			attribs = @attributes.empty? ? "" : " #{@attributes}"
			"<#{@prefix}:#{@name}#{attribs}>"
		end
	end
end

