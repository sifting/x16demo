import math
import struct

#Generate the sine table, mirroring the first half for accuracy
tbl = 256*[0]
for i in range (128):
    x = int (0x7f*math.sin (math.pi*i/127.5))
    tbl[i] = x
    tbl[128 + i] = -x;
#Cosine table overlaps with the sine table
tbl += tbl[0:64]
#Fix up some key values for more precision
tbl[0] = 0
tbl[63] = 127
tbl[64] = 127
tbl[128] = 0
tbl[191] = -127
tbl[192] = -127
tbl[319] = 127
#Dump table to disk
with open ('sines.bin', 'wb') as f:
    f.write (struct.pack (f'{len(tbl)}b', *tbl))