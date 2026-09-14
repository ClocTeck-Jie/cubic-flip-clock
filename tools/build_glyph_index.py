"""Index existing LVGL glyph records so Lua can seek only visible characters."""
from pathlib import Path
import struct
root=Path(__file__).resolve().parents[1]/'package'
for size in (12,13,16):
 data=(root/f'chinese{size}.bin').read_bytes();tables={};pos=0
 while pos<len(data):
  length,label=struct.unpack_from('<I4s',data,pos);assert length>=8
  tables[label]=(pos,data[pos:pos+length]);pos+=length
 head=tables[b'head'][1];cmap=tables[b'cmap'][1];loca=tables[b'loca'][1];glyf_base,glyf=tables[b'glyf']
 fmt='I' if head[34] else 'H';count=struct.unpack_from('<I',loca,8)[0]
 offsets=list(struct.unpack_from('<'+fmt*count,loca,12))+[len(glyf)]
 index=bytearray(65536*8);mapping={}
 for n in range(struct.unpack_from('<I',cmap,8)[0]):
  off,start,length,gid,total,kind=struct.unpack_from('<IIHHHB',cmap,12+n*16)
  if kind==2:pairs=[(start+i,gid+i) for i in range(length)]
  elif kind==0:pairs=[(start+i,gid+cmap[off+i]) for i in range(length)]
  else:
   codes=struct.unpack_from('<'+'H'*total,cmap,off)
   ids=range(total) if kind==3 else struct.unpack_from('<'+'H'*total,cmap,off+total*2)
   pairs=[(start+c,gid+i) for c,i in zip(codes,ids)]
  for cp,g in pairs:
   if cp>65535:continue
   a,b=offsets[g:g+2];assert b>=a
   struct.pack_into('<II',index,cp*8,glyf_base+a,b-a);mapping[cp]=data[glyf_base+a:glyf_base+b]
 # Header is copied at runtime with no kerning, 32-bit loca and 8-bit glyph IDs.
 assert all(len(v)<2048 for v in mapping.values())
 (root/f'glyph{size}.idx').write_bytes(index)
 print(size,len(mapping),'indexed glyphs')
