"""Regenerate the local UI font with fontTools 4.68.0; keep the upstream OFL file."""
import json
from pathlib import Path
from fontTools import subset
from fontTools.ttLib import TTFont

app = Path(__file__).resolve().parents[1]
source = app / 'tool/fonts/NotoSansSC-Regular.otf'
target = app / 'assets/fonts/NotoSansSC-Regular.otf'
font = TTFont(source, recalcTimestamp=False)
original = set(font.getBestCmap())

def han(code):
    return any(start <= code <= end for start, end in (
        (0x3400, 0x9FFF), (0xF900, 0xFAFF), (0x20000, 0x323AF)))

# GB2312 includes 6,763 common Chinese characters, including current typhoon names.
common = set()
for lead in range(0xB0, 0xF8):
    for trail in range(0xA1, 0xFF):
        try:
            common.update(map(ord, bytes([lead, trail]).decode('gb2312')))
        except UnicodeDecodeError:
            pass
texts = list((app / 'lib').rglob('*.dart'))
texts += list((app.parent / 'data').glob('latest.json'))
texts += list((app.parent / 'data/raw').glob('year-*.json'))
used = set().union(*(set(map(ord, path.read_text(encoding='utf-8')))
                         for path in texts))
keep = (common | used | {code for code in original if not han(code)}) & original
options = subset.Options()
options.name_IDs = ['*']
subsetter = subset.Subsetter(options=options)
subsetter.populate(unicodes=keep)
subsetter.subset(font)

# Give the modified font its own name while retaining copyright and OFL metadata.
names = {1: 'Typhoon Sans SC', 2: 'Regular', 3: 'TyphoonSansSC-Regular',
         4: 'Typhoon Sans SC Regular', 6: 'TyphoonSansSC-Regular',
         16: 'Typhoon Sans SC', 17: 'Regular'}
for record in font['name'].names:
    if record.nameID in names:
        record.string = names[record.nameID].encode(record.getEncoding())
if 'CFF ' in font:
    font['CFF '].cff.fontNames = ['TyphoonSansSC-Regular']
    top = font['CFF '].cff.topDictIndex[0]
    top.FamilyName = 'Typhoon Sans SC'
    top.FullName = 'Typhoon Sans SC Regular'
font.save(target)
result = TTFont(target)
assert keep <= set(result.getBestCmap()), 'Required characters lost during subsetting'
assert target.stat().st_size <= 2_500_000, 'Startup font exceeds payload budget'
print(json.dumps({'originalBytes': source.stat().st_size,
                  'subsetBytes': target.stat().st_size,
                  'characters': len(result.getBestCmap()),
                  'knownTextCoverage': len(used & original)}, ensure_ascii=False))
