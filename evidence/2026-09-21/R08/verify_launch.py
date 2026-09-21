"""Bounded custom HC11 path interpreter: only instructions required by this test.
No IRQ, timing, upstream bypass, bank switching or physical output simulation.
"""
def run(image,speed,rpm,state,gear,rangebit):
 m=bytearray(65536);m[:0x8000]=image[:0x8000];m[0x8000:]=image[0x10000:0x18000]
 m[0x98]=speed;m[0xa2]=rpm;m[0x5f]=state*64;m[0x41]=gear;m[0xdc]=rangebit
 for a in (0x143,0x145,0x13f,0x141):m[a:a+2]=b'\x12\x34'
 pc=0xa582;sp=0x1fff;A=0x5a;B=0xa5;X=0x1357;C=0;Z=0;steps=0;selected=None
 def byte():
  nonlocal pc
  v=m[pc];pc=(pc+1)&65535;return v
 def word():return byte()*256+byte()
 def push(v):
  nonlocal sp
  m[sp]=v;sp-=1
 def pop():
  nonlocal sp
  sp+=1;return m[sp]
 while pc not in (0xa647,0xa5d8):
  steps+=1
  if steps>120:raise RuntimeError('instruction cap')
  addr=pc;op=byte()
  if op==0xbd:
   dest=word();push(pc&255);push(pc>>8);pc=dest
  elif op==0x39:pc=pop()*256+pop()
  elif op==0x36:push(A)
  elif op==0x32:A=pop()
  elif op==0xce:X=word()
  elif op==0x96:A=m[byte()]
  elif op==0xd6:B=m[byte()]
  elif op in (0x81,0xb1,0xa1,0xf1):
   v=byte() if op==0x81 else m[word()] if op in (0xb1,0xf1) else m[(X+byte())&65535]
   q=B if op==0xf1 else A;C=int(q<v);Z=int(q==v)
   if addr==0xa5bc:selected=X
  elif op in (0x20,0x22,0x23,0x24,0x25):
   d=byte();d=d if d<128 else d-256
   if {0x20:True,0x22:not C and not Z,0x23:C or Z,0x24:not C,0x25:bool(C)}[op]:pc=(pc+d)&65535
  elif op in (0x12,0x13):
   a=byte();mask=byte();d=byte();d=d if d<128 else d-256
   yes=(m[a]&mask)==mask if op==0x12 else (m[a]&mask)==0
   if yes:pc=(pc+d)&65535
  elif op in (0x14,0x15):
   a=byte();mask=byte();m[a]=(m[a]|mask) if op==0x14 else (m[a]&~mask)
  elif op==0x08:X=(X+1)&65535
  elif op==0x09:X=(X-1)&65535
  elif op==0xff:
   a=word();m[a]=X>>8;m[a+1]=X&255
  elif op==0x7e:pc=word()
  else:raise RuntimeError(f'unsupported {op:02x} at {addr:04x}')
 assert sp==0x1fff and B==0xa5 or (sp==0x1fff and B==rpm) # stock speed-protection branch loads B
 return {'cut':bool(m[0x5f]&64),'pc':pc,'selected':selected,'sp':sp,'X':X,'A':A,'B':B,'words':[m[a:a+2].hex() for a in (0x143,0x145,0x13f,0x141)]}

if __name__=='__main__':
 import sys,json
 from pathlib import Path
 from build_launch_patch import build,HOOK,OFF
 if len(sys.argv)!=3:raise SystemExit('Usage: python verify_launch.py original.bin patched.bin')
 base=Path(sys.argv[1]).read_bytes();b=Path(sys.argv[2]).read_bytes()
 assert b==build(base),'Output is not the default builder result for this base'
 disabled=bytearray(b);disabled[HOOK:HOOK+3]=OFF
 counts={'low_speed_cases':0,'moving_cases':0,'off_cases':0}
 for rpm in range(256):
  for state in (0,1):
   for gear in (0,1,8,9,12,13,14,15):
    for rb in (0,32):
     for speed in (0,1,2):
      assert run(b,speed,rpm,state,gear,rb)['cut']==(rpm>80);counts['low_speed_cases']+=1
     for speed in (3,10,11,127,253,254,255):
      assert run(b,speed,rpm,state,gear,rb)==run(base,speed,rpm,state,gear,rb);counts['moving_cases']+=1
     assert run(disabled,0,rpm,state,gear,rb)==run(base,0,rpm,state,gear,rb);counts['off_cases']+=1
 print(json.dumps(counts,indent=2));print('PASS: bounded path only; not a full PCM emulator or hardware validation')
