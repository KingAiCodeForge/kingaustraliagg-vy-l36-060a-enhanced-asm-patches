#!/usr/bin/env python3
"""Decode one already-captured VY Mode-1 Table-8 response, read-only.
The response does not echo its table number: the caller MUST know it came from
Table 8. This tool never sends a request and does not access a serial device.
Returns raw values unless a bit meaning was matched to its producer.
"""
from __future__ import annotations
import argparse,json
from pathlib import Path
from ecotec_diag import sha,ContractError

def decode_frame(frame:bytes, engineering:dict)->dict:
    d=engineering['descriptor'];count=d['payload_bytes']
    if len(frame)!=count+4:raise ContractError('Unexpected complete frame length')
    if frame[0]!=d['response_id'] or frame[1]!=count+1+0x55 or frame[2]!=1:
        raise ContractError('Wrong response ID, length encoding, or mode')
    if sum(frame)&255:raise ContractError('Additive frame checksum mismatch')
    payload=frame[3:-1];fields=[];values={}
    for f in d['fields']:
        raw=payload[f['offset']:f['offset']+f['width']]
        val=int.from_bytes(raw,'big');values[f['symbol']]=val
        fields.append(dict(symbol=f['symbol'],offset=f['offset'],width=f['width'],
                           raw_hex=raw.hex(),raw_unsigned=val,meaning_status='SOURCE_CORRELATED_SLOT'))
    flags={}
    for p in engineering['packers']:
        v=values[p['symbol']]
        flags[p['symbol']]={r['input_bit_symbol']:bool(v&r['output_mask']) for r in p['bits']}
    return dict(status='DECODED_OFFLINE_NOT_A_HARDWARE_VERDICT',table_number_assumed_from_request=8,
        payload_bytes=count,checksum_ok=True,fields=fields,producer_matched_flags=flags,
        timing_limit='Individual words latch both bytes; the whole frame is not a simultaneous snapshot. Engineering state packing is a separate scheduled operation.')

def main():
    ap=argparse.ArgumentParser(description=__doc__);ap.add_argument('--bin',type=Path,required=True)
    ap.add_argument('--contracts',type=Path,required=True);ap.add_argument('--frame-hex',required=True)
    a=ap.parse_args();digest=sha(a.bin.read_bytes());ps=json.loads(a.contracts.read_text())['images']
    matches=[p for p in ps if p['sha256']==digest and 'engineering' in p]
    if len(matches)!=1:raise ContractError('Exact supported firmware not found')
    frame=bytes.fromhex(a.frame_hex);print(json.dumps(decode_frame(frame,matches[0]['engineering']),indent=2))
if __name__=='__main__':main()
