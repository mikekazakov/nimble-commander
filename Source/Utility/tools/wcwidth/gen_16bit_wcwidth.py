#!/usr/bin/python3
# http://www.unicode.org/reports/tr11/
# http://www.unicode.org/Public/UNIDATA/EastAsianWidth.txt

import sys
import os

ranges = []

def process_line(line):
    # e.g.:
    # FF41..FF5A;F
    # 1F946;N    
    # 1F947..1F9FF;W    
    hash_pos = line.find('#')
    if hash_pos != -1:
        line = line[:hash_pos]
    line = line.strip(' ')
    if len(line) == 0:
        return
    semi = line.find(';')
    if semi == -1:
        return
    category = line[semi+1:]
    ell = line.find('..')
    start = ''
    end = ''
    if ell == -1:
        start = line[:semi]
        end = start
    else:
        start = line[:ell]
        end = line[ell+2:semi]
    ranges.append( ( int(start, 16), int(end, 16), category) )

for line in open("EastAsianWidth.txt", "r"):
    process_line(line)

fw_flags = [int(0)] * 1024

for interval in ranges:
    if interval[2] == 'F' or interval[2] == 'W':
        for i in range(interval[0], interval[1]+1):
            if i <= 0xFFFF:
                idx = i // 64
                bit = i % 64
                fw_flags[idx] = fw_flags[idx] | ( 1 << bit)

print( 'const uint64_t CharInfo::g_WCWidthTableIsFullSize[1024] = {' )
for row in range(0, 256):
    print(
    '0x{:016x}UL, '.format(fw_flags[row*4 + 0]),
    '0x{:016x}UL, '.format(fw_flags[row*4 + 1]),
    '0x{:016x}UL, '.format(fw_flags[row*4 + 2]),
    '0x{:016x}UL, '.format(fw_flags[row*4 + 3]))
print( '};' )
