#!/usr/bin/env ruby

require 'stringio'
require 'types'

test_cases = {
"EndElement" => "\x40\x03\x64\x6F\x63\x01",
#<doc></doc>
"Comment" => "\x02\x07\x63\x6F\x6D\x6D\x65\x6E\x74",
#<!--comment-->
"Array" => "\x03\x40\x03\x61\x72\x72\x01\x8B\x03\x33\x33\x88\x88\xDD\xDD",
#<arr>13107</arr> <arr>-30584</arr> <arr>-8739</arr>
"ShortAttribute" => "\x40\x03\x64\x6F\x63\x04\x04\x61\x74\x74\x72\x84\x01",
#<doc attr="false"> </doc>
#"Attribute" => "\x40\x03\x64\x6F\x63\x09\x03\x70\x72\x65\x0A\x68\x74\x74\x70\x3A\x2F\x2F\x61\x62\x63\x05\x03\x70\x72\x65\x04\x61\x74\x74\x72\x84\x01"
#<doc xmlns: pre="http://abc " pre:attr="false"> </doc>
}

test_cases.each_pair{|type, data|
	puts "Testing #{type}"
	ss = StringIO.new(data)
	MSBIN::Record.DecodeStream(ss)
}