#!/usr/bin/env python

import sys

start = 0xBE
end = 0xFE
word = "Reserved"

for i in range(start,end+1):
	print '0x%02X  %s'%(i,word)#,chr(ord('A')+i-start))

