#!/usr/bin/env python3
"""Target-specific 060A Enhanced R08 all-range launch diagnostic builder.
Python 3 standard library only. Never overwrites an input or existing output.
R08 keeps the user-tested R07b routine unchanged; packaging/calibration provenance differs.
"""
from pathlib import Path
import argparse, hashlib, json, xml.etree.ElementTree as ET
HOOK=0x12582; ROUTINE=0x17EC0; SHADOW=0x17F00
OFF=bytes.fromhex('CE77DE'); ON=bytes.fromhex('BDFEC0')
CODE=bytes.fromhex('36969881022205CEFF002003CE77DE3239')
START=0x12540
SIGNATURE=bytes.fromhex('12298003BDECD7135280601359041196A2B170A222079683B170A122631559041267805C125F025B133D8016B61AE08504270FF61AE1135F4002C008D1A225402053CE77DE135F4001089698134108020808A1062507D6A2F177DD242313410819090913DC20060808200D2028134101099698B177DC2202080896A2A1002315145F40CE0000FF0143FF0145FF013FFF01417EA647155F40')
def sha(b):return hashlib.sha256(b).hexdigest()
def validate_base(b):
 if len(b)!=0x20000:raise ValueError('Requires a full 131072-byte BIN')
 if b[START:START+len(SIGNATURE)]!=SIGNATURE:raise ValueError('Limiter code mismatch: incompatible or already patched; do not force')
 if any(b[ROUTINE:SHADOW+64]):raise ValueError('Patch space is occupied; do not overwrite another modification')
 if b[0x4008]!=0xAA:raise ValueError('Checksum bypass is not already present. This builder does not disable or recalculate checksums; independent checksum support required')
def validate_installed(b):
 if len(b)!=0x20000 or b[HOOK:HOOK+3] not in (ON,OFF):raise ValueError('Unrecognized hook')
 c=bytearray(b);c[HOOK:HOOK+3]=OFF
 if c[START:START+len(SIGNATURE)]!=SIGNATURE:raise ValueError('Limiter code differs')
 if b[ROUTINE:ROUTINE+4]!=CODE[:4] or b[ROUTINE+5:ROUTINE+17]!=CODE[5:]:raise ValueError('Selector code differs')
 if b[SHADOW:SHADOW+6]==bytes(6):raise ValueError('Uninitialized launch thresholds')
def put(parent,tag,text=None,**attrs):
 e=ET.SubElement(parent,tag,attrs)
 if text is not None:e.text=str(text)
 return e
def entries(base,cat=1):
 out=[];uid=0x6B80
 def patch(title,desc,parts):
  nonlocal uid
  e=ET.Element('XDFPATCH',uniqueid=hex(uid));uid+=1
  put(e,'title',title);put(e,'description',desc);put(e,'CATEGORYMEM',index='0',category=str(cat))
  for name,a,old,new in parts:
   assert len(old)==len(new)
   put(e,'XDFPATCHENTRY',name=name,address=hex(a),datasize=hex(len(new)),basedata=old.hex().upper(),patchdata=new.hex().upper())
  out.append(e)
 shadow=bytes([80]*6)+base[0x77E4:0x781E]
 guards=[('Code_signature',START,SIGNATURE,SIGNATURE),('Target_calibrations',0x77DE,base[0x77DE:0x781E],base[0x77DE:0x781E]),('Unused_gap',ROUTINE+17,bytes(SHADOW-ROUTINE-17),bytes(SHADOW-ROUTINE-17))]
 patch('LC R08 - 1 INSTALL (starts OFF)',
 'ONE-TIME installation into the exact matching unpatched target. Stop on ANY original-data mismatch. Initializes 2000/2000 RPM, raw speed <=2, all ranges. Then use ON. Do not reinstall to toggle; it resets settings. Full BIN programming required. Target SHA256 '+sha(base),
 guards+[('Selector',ROUTINE,bytes(17),CODE),('Target_shadow',SHADOW,bytes(64),shadow)])
 cg=[('Selector_prefix',ROUTINE,CODE[:4],CODE[:4]),('Selector_suffix',ROUTINE+5,CODE[5:],CODE[5:])]
 patch('LC R08 - 2 ON (after INSTALL)',
 'Enable installed R08 by selecting JSR $FEC0. Retains launch settings. All ranges including Park/Neutral/Reverse. Stop on mismatch. Full BIN write required.',cg+[('Hook_ON',HOOK,OFF,ON)])
 patch('LC R08 - 3 OFF (factory limiter)',
 'Restore LDX #$77DE at the hook. Factory limiter path resumes; selector and launch settings remain stored for later ON. Full BIN write required. This does not undo unrelated tune changes.',cg+[('Hook_OFF',HOOK,ON,OFF)])
 def scalar(title,address,equation,units,desc,maxval):
  nonlocal uid
  e=ET.Element('XDFCONSTANT',uniqueid=hex(uid));uid+=1
  put(e,'title',title);put(e,'description',desc);put(e,'CATEGORYMEM',index='0',category=str(cat))
  put(e,'EMBEDDEDDATA',mmedaddress=hex(address),mmedelementsizebits='8',mmedmajorstridebits='0',mmedminorstridebits='0')
  put(e,'units',units);put(e,'decimalpl','0');put(e,'min','0');put(e,'max',maxval);put(e,'outputtype','1');put(e,'datatype','0');put(e,'unittype','0');put(e,'DALINK',index='0')
  m=put(e,'MATH',equation=equation);put(m,'VAR',id='X');out.append(e)
 for i in range(3):
  scalar(f'LC R08 - Pair {i+1} CUT RPM',SHADOW+i*2,'X*25','RPM','Set ALL THREE cut values identically for this all-range diagnostic. Cut when sampled RPM is strictly greater than this value. 25 RPM resolution. Full BIN write.',6375)
  scalar(f'LC R08 - Pair {i+1} RESTART RPM',SHADOW+i*2+1,'X*25','RPM','Set ALL THREE restart values identically and no higher than cut. Fuel resumes at or below this value. Default 2000 matches R07b. Equal cut/restart still has 25 RPM quantization. Full BIN write.',6375)
 scalar('LC R08 - Speed gate RAW COUNTS',ROUTINE+4,'X','RAW','Launch selected at RAM $98 <= this raw byte. Default 2 retains tested R07b. NOT confirmed km/h. No brake/TPS/Drive/clutch gate or latch. Do not raise without verifying scaling and release behaviour. Full BIN write.',255)
 return out

def xdf(base):
 root=ET.Element('XDFFORMAT',version='1.80');h=put(root,'XDFHEADER')
 put(h,'flags','0x1');put(h,'deftitle','MCS 060A Enhanced LC R08 - target-specific all-range REVIEW')
 put(h,'description','Launch-only definition. Matched target SHA256 '+sha(base)+'. No spark-cut patch. Derived from corrected, user-tested R07b. R08 port is not vehicle-validated. Read README. All changes require full BIN writes.')
 put(h,'author','Muncies Chop Shop; factory 060A Enhanced base by The1; R07b-derived patch')
 put(h,'BASEOFFSET',offset='0',subtract='0');put(h,'DEFAULTS',datasizeinbits='8',sigdigits='2',outputtype='1',signed='0',lsbfirst='0',float='0')
 put(h,'REGION',type='0xFFFFFFFF',startaddress='0x0',size='0x20000',regioncolor='0x0',regionflags='0x0',name='Full BIN',desc='128 KiB')
 put(h,'CATEGORY',index='0x0',name='MCS Launch R08 - REVIEW')
 root.extend(entries(base));ET.indent(root,space='  ')
 return ET.tostring(root,encoding='utf-8',xml_declaration=True)
def build(base):
 validate_base(base);b=bytearray(base)
 b[ROUTINE:ROUTINE+17]=CODE;b[SHADOW:SHADOW+64]=bytes([80]*6)+base[0x77E4:0x781E];b[HOOK:HOOK+3]=ON
 return bytes(b)
def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('action',choices=['build','on','off']);p.add_argument('input',type=Path);p.add_argument('output',type=Path);a=p.parse_args();src=a.input.read_bytes()
 if a.output.resolve()==a.input.resolve() or a.output.exists():p.error('Output must be a new file')
 if a.action=='build':
  b=build(src);xp=a.output.with_suffix('.xdf');mp=a.output.with_suffix('.manifest.json')
  if xp.exists() or mp.exists():p.error('Sidecar output already exists')
  xp.write_bytes(xdf(src));mp.write_text(json.dumps({'source_sha256':sha(src),'output_sha256':sha(b),'changed_offsets':[hex(i) for i in range(len(b)) if b[i]!=src[i]],'state':'ON','variant':'R08 all-range R07b-derived','checksum':'existing AA bypass preserved'},indent=2))
 else:
  validate_installed(src);b=bytearray(src);b[HOOK:HOOK+3]=ON if a.action=='on' else OFF;b=bytes(b)
 a.output.write_bytes(b);print(a.output,sha(b))
if __name__=='__main__':main()
