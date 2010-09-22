#!/usr/bin/env ruby

require 'rubygems'
require 'xmlsimple'

#xml = $stdin.read

puts XmlSimple.xml_in($stdin.read)
