
module MSBIN
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
		define_with_endelement
		def to_s; "0"; end
	end

	class TrueText < TextRecord
		@record_type = 0x86
		define_with_endelement
		def to_s; "true"; end
	end

	# TODO: make this derive from TextRecord
	class FalseText < TextRecord
		@record_type = 0x84
		define_with_endelement
		def to_s; "false"; end
	end

	class OneText < TextRecord
		@record_type = 0x82
		define_with_endelement
		def to_s; "1"; end
	end

	# TODO: Parse this better
	class DateTimeText < TextRecord
		@record_type = 0x96

		define_with_endelement

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

	class DictionaryText < TextRecord
		@record_type = 0xaa

		define_with_endelement

		def initialize(handle, record_type)
			@value = read_dictstring(handle)
		end
	end

	class Chars8Text < TextRecord
		@record_type = 0x98

		define_with_endelement

		def initialize(handle, record_type)
			require 'cgi'
			length = handle.read(1)[0]
			@value = CGI.escapeHTML(handle.read(length)).to_s
		end
	end

	class Chars16Text < TextRecord
		@record_type = 0x9a

		define_with_endelement

		def initialize(handle, record_type)
			require 'cgi'
			length = handle.read(2).unpack("n")[0]
			@value = CGI.escapeHTML(handle.read(length)).to_s
		end
	end

	class Chars32Text < TextRecord
		@record_type = 0x9c

		define_with_endelement

		def initialize(hand,record_type)
			require 'cgi'
			length = handle.read(4).unpack("l")[0]
			@value = CGI.escapeHTML(handle.read(length)).to_s
		end
	end

	class UuIdText < TextRecord
		@record_type = 0xac

		define_with_endelement

		def initialize(handle, record_type)
			@uuid = handle.read(16).unpack('VvvC*')
			@value = ("%08x-%04x-%04x-" % [@uuid[0], @uuid[1], @uuid[2]])+(("%02x"*6) % @uuid[3..-1])
		end
	end

	class TimeSpanText < TextRecord
		@record_type = 0xae

		define_with_endelement

		def initialize(handle, record_type)
			@value = handle.read(8).unpack("q")[0]
			if @value < 0
				@sign = '-'; @value *= -1
			end

			ticks_in_sec = 10000000
			@frac    = @value % ticks_in_sec; @value /= ticks_in_sec
			@seconds = @value % 60; @value /= 60
			@minutes = @value % 60; @value /= 60
			@hours   = @value % 24; @value /= 24
			@days    = @value
		end

		def to_s
			if @days > 0 and @frac == 0
				"#{@sign}%d.%02d:%02d:%02d" %    [@days, @hours, @minutes, @seconds]
			elsif @days > 0 and @frac > 0
				"#{@sign}%d.%02d:%02d:%02d:%d" % [@days, @hours, @minutes, @seconds, @frac]
			elsif @days == 0 and @frac == 0
				"#{@sign}%02d:%02d:%02d" %              [@hours, @minutes, @seconds]
			else
				"#{@sign}%02d:%02d:%02d.%d" %           [@hours, @minutes, @seconds, @frac]
			end
		end
	end

	class Int8Text < TextRecord
		@record_type = 0x88

		define_with_endelement

		def initialize(handle, record_type)
			@value = handle.read(1)[0].to_s
		end
	end

	class Int16Text < TextRecord
		@record_type = 0x8a

		define_with_endelement

		def initialize(handle, record_type)
			@value = handle.read(2).unpack("n")[0].to_s
		end
	end

	class Int32Text < TextRecord
		@record_type = 0x8c

		define_with_endelement

		def initialize(handle, record_type)
			@value = handle.read(4).unpack("l")[0].to_s
		end
	end

	class Int64Text < TextRecord
		@record_type = 0x8e

		define_with_endelement

		def initialize(handle, record_type)
			@value = handle.read(8).unpack("q")[0].to_s
		end
	end

	class FloatText < TextRecord
		@record_type = 0x90

		define_with_endelement

		def initialize(handle, record_type)
			@value = handle.read(4).unpack("g")[0].to_s
		end
	end

	class DoubleText < TextRecord
		@record_type = 0x92

		define_with_endelement

		def initialize(handle, record_type)
			@value = handle.read(8).unpack("E")[0].to_s
		end
	end

	class DecimalText < TextRecord
		@record_type = 0x94

		define_with_endelement

		def initialize(handle, record_type)
			wReserved = handle.read(2).unpack("n")[0]
			scale = handle.read(1)[0]
			@sign = handle.read(1)[0] == 0 ? "" : "-"
			@value = 0
			2.downto(0).each {|n|
				@value |= (handle.read(4).unpack("N")[0]) << 32*n
				puts "#{@value.to_s 16}"
			}
			@value /= 10.0**scale
		end

		def to_s
			"#{@sign}#{@value}"
		end
	end

	class UnicodeChars8Text < TextRecord
		@record_type = 0xb6

		define_with_endelement

		def initialize(handle, record_type)
			length = handle.read(1)[0]
			@value = from_unicode(handle.read(length))
		end
	end

	class UnicodeChars16Text < TextRecord
		@record_type = 0xb8

		define_with_endelement

		def initialize(handle, record_type)
			length = handle.read(2).unpack("n")[0]
			@value = from_unicode(handle.read(length))
		end
	end

	class UnicodeChars32Text < TextRecord
		@record_type = 0xba

		define_with_endelement

		def initialize(handle, record_type)
			length = handle.read(4).unpack("l")[0]
			@value = from_unicode(handle.read(length))
		end
	end

	class BoolText < TextRecord
		@record_type = 0xb4

		define_with_endelement

		def initialize(handle, record_type)
			val = handle.read(1)[0]
			@value = val == 0 ? "false" : "true"
		end
	end

	class UInt64Text < TextRecord
		@record_type = 0xb2

		define_with_endelement

		def initialize(handle, record_type)
			@value = handle.read(8).unpack("Q")[0].to_s
		end
	end

	class StartListText < TextRecord
		@record_type = 0xa4

		def initialize(handle, record_type)
			@records = []
			begin
				record = Record.MakeRecord(handle)
				@records << record
			end until record.is_a?(EndListText)
		
			@value = @records.map{|x|x.strip}.join(" ")
		end
	end

	class EndListText < TextRecord
		@record_type = 0xa6
		def to_s; ""; end
	end

	class EmptyText < TextRecord
		@record_type = 0xa8
		define_with_endelement
		def to_s; ""; end
	end

	class QNameDictionaryText < TextRecord
		@record_type = 0xbc

		define_with_endelement

		def initialize(handle, record_type)
			val = handle.read(4).unpack("L")[0]
			@prefix = (((val >> 24) & 0xff) + ?a).chr
			val &= 0x00ffffff
			@value = "#{@prefix}:#{MSBIN_DictionaryStrings[val]}"
		end
	end

	class Bytes8Text < TextRecord
		@record_type = 0x9e

		define_with_endelement

		# TODO: Rewrite all these custom reads to util funcs
		def initialize(handle, record_type)
			length = handle.read(1)[0]
			bytes = handle.read(length)

			require 'base64'
			@value = Base64.b64encode(bytes).rstrip
		end
	end

	class Bytes16Text < TextRecord
		@record_type = 0xa0

		define_with_endelement

		# TODO: factor out everything but length
		def initialize(handle, record_type)
			length = handle.read(2).unpack("n")[0]
			bytes = handle.read(length)

			require 'base64'
			@value = Base64.b64encode(bytes).rstrip
		end
	end

	class Bytes32Text < TextRecord
		@record_type = 0xa2

		define_with_endelement

		def initialize(handle, record_type)
			length = handle.read(4).unpack("l")[0]
			bytes = handle.read(length)

			require 'base64'
			@value = Base64.b64encode(bytes).rstrip
		end
	end
end
