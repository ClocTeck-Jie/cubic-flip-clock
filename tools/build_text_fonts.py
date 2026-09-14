"""Build SD glyph banks from an OFL font, then create the seek indexes."""
from pathlib import Path
import argparse, subprocess, sys
root=Path(__file__).resolve().parents[1]
parser=argparse.ArgumentParser();parser.add_argument('--source',type=Path);args=parser.parse_args()
if args.source:
    from fontTools.ttLib import TTFont
    font=TTFont(args.source)
    license_text=' '.join(n.toUnicode() for n in font['name'].names if n.nameID==13)
    assert 'Open Font License' in license_text,'An OFL source font is required'
    text=''.join(p.read_text(encoding='utf8') for p in (root/'package').glob('*.lua'))
    for size in (12,13,16):
        subprocess.run(['node',str(root/'node_modules/lv_font_conv/lv_font_conv.js'),'--font',str(args.source),
            '--range','0x20-0x17F,0x3000-0x30FF'+(',0x4E00-0x9FFF' if size==12 else ''),
            '--symbols',''.join(sorted(set(text))),'--size',str(size),'--bpp','4','--format','bin','--no-compress',
            '-o',str(root/f'package/chinese{size}.bin')],check=True)
subprocess.run([sys.executable,str(root/'tools/build_glyph_index.py')],check=True)
