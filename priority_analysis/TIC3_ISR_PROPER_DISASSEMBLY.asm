======================================================================
VY V6 TIC3 ISR DISASSEMBLY (3X Crank Handler)
This is the SPARK CUT injection point!
======================================================================

TIC3 ISR starts at: $35FF

35FF: 86 01        LDAA   #$01
3601: B7 10 23     STAA   $1023
3604: 7C 1B 8C     INC    $1B8C
3607: 7C 18 E5     INC    $18E5
360A: 13 46 01 0E  BRCLR  $46,#$01,$361C
360E: 12 48 01 04  BRSET  $48,#$01,$3616
3612: 13 44 10 06  BRCLR  $44,#$10,$361C
3616: 15 48 01     BCLR   $48,#$01
3619: 7E 37 19     JMP    $3719
361C: 03           PULB   
361D: 03           PULB   
361E: F6 01 6D     LDAB   $016D
3621: CE 68 52     LDX    #$6852
3624: 3A           ABX    
3625: E6 00        LDAB   $00,X
3627: 4F           CLRA   
3628: 8F           XGDX   
3629: 3C           PSHX   
362A: 30           TSX    
362B: FC 01 B3     LDD    $01B3
362E: A3 00        SUBD   $00,X
3630: 38           PULX   
3631: BD 37 1A     JSR    $371A  ; <<< SUBROUTINE CALL
3634: B7 01 7D     STAA   $017D
3637: B6 15 CA     LDAA   $15CA
363A: 01           NOP    
363B: FC 15 CA     LDD    $15CA
363E: FD 01 78     STD    $0178
3641: F6 01 71     LDAB   $0171
3644: CE 36 50     LDX    #$3650
3647: 7C 01 71     INC    $0171
364A: 58           ASLB   
364B: 3A           ABX    
364C: EE 00        LDX    $00,X
364E: 6E           ???
364F: 00           ???
3650: 36           PSHA   
3651: 5C           INCB   
3652: 36           PSHA   
3653: 67           ???
3654: 36           PSHA   
3655: 7D           ???
3656: 36           PSHA   
3657: 8F           XGDX   
3658: 36           PSHA   
3659: A0           ???
365A: 36           PSHA   
365B: AB           ???
365C: FC 01 78     LDD    $0178
365F: B3 1B 7A     SUBD   $1B7A
3662: FD 1B 7C     STD    $1B7C
3665: 20 37        BRA    $369E
3667: FC 01 78     LDD    $0178
366A: B3 1B 7A     SUBD   $1B7A
366D: FD 1B 7E     STD    $1B7E
3670: B6 01 7D     LDAA   $017D
3673: 81 AB        CMPA   #$AB
3675: 22 27        BHI    $369E
3677: 80 72        SUBA   #$72
3679: 25 1D        BCS    $3698
367B: 20 57        BRA    $36D4
367D: FC 01 78     LDD    $0178
3680: B3 1B 7A     SUBD   $1B7A
3683: FD 1B 80     STD    $1B80
3686: B6 01 7D     LDAA   $017D
3689: 80 AB        SUBA   #$AB
368B: 25 0B        BCS    $3698
368D: 20 2A        BRA    $36B9
368F: FC 01 78     LDD    $0178
3692: B3 1B 7A     SUBD   $1B7A
3695: FD 1B 82     STD    $1B82
3698: FC 01 78     LDD    $0178
369B: FD 14 5C     STD    $145C
369E: 20 73        BRA    $3713
36A0: FC 01 78     LDD    $0178
36A3: B3 1B 7A     SUBD   $1B7A
36A6: FD 1B 84     STD    $1B84
36A9: 20 68        BRA    $3713
36AB: FC 01 78     LDD    $0178
36AE: B3 1B 7A     SUBD   $1B7A
36B1: FD 1B 86     STD    $1B86
36B4: 7F 01 71     CLR    $0171
36B7: 20 5A        BRA    $3713
36B9: 36           PSHA   
36BA: FC 1B 7C     LDD    $1B7C
36BD: FE 1B 7E     LDX    $1B7E
36C0: 03           PULB   
36C1: FC 1B 80     LDD    $1B80
36C4: BD 23 BA     JSR    $23BA  ; <<< SUBROUTINE CALL

======================================================================
TIC2 ISR (24X Crank) at $358A
======================================================================

358A: 86 02        LDAA   #$02
358C: B7 10 23     STAA   $1023
358F: F6 01 6D     LDAB   $016D
3592: F7 1C 38     STAB   $1C38
3595: CE 35 84     LDX    #$3584
3598: 3A           ABX    
3599: E6 00        LDAB   $00,X
359B: F7 1C 37     STAB   $1C37
359E: FC 1C 33     LDD    $1C33
35A1: F3 10 12     ADDD   $1012
35A4: CE 10 00     LDX    #$1000
35A7: 1C           ???
35A8: 22 20        BHI    $35CA
35AA: 1C           ???
35AB: 20 30        BRA    $35DD
35AD: FD 10 1A     STD    $101A
35B0: A3 0E        SUBD   $0E,X
35B2: 2A 08        BPL    $35BC
35B4: EC 0E        LDD    $0E,X
35B6: C3           ???
35B7: 00           ???
35B8: 02           ???
35B9: FD 10 1A     STD    $101A
35BC: 3B           RTI      ; <<< END OF ISR
35BD: 86 20        LDAA   #$20
35BF: B7 10 23     STAA   $1023
35C2: F6 10 00     LDAB   $1000
35C5: 17           TBA    
35C6: C4 18        ANDB   #$18
35C8: 37           PSHB   

======================================================================
TOC3 ISR (EST Output) at $35BD
======================================================================

35BD: 86 20        LDAA   #$20
35BF: B7 10 23     STAA   $1023
35C2: F6 10 00     LDAB   $1000
35C5: 17           TBA    
35C6: C4 18        ANDB   #$18
35C8: 37           PSHB   
35C9: 8A 10        ORAA   #$10
35CB: 84 F7        ANDA   #$F7
35CD: B7 10 00     STAA   $1000
35D0: BD 88 B0     JSR    $88B0  ; <<< SUBROUTINE CALL
35D3: F6 10 00     LDAB   $1000
35D6: C4 E7        ANDB   #$E7
35D8: 32           PULA   
35D9: 1B           ABA    
35DA: B7 10 00     STAA   $1000
35DD: 3B           RTI      ; <<< END OF ISR
35DE: 86 10        LDAA   #$10
35E0: B7 10 23     STAA   $1023
35E3: F6 10 00     LDAB   $1000
35E6: 17           TBA    
35E7: C4 18        ANDB   #$18
35E9: 37           PSHB   
35EA: 8A 10        ORAA   #$10
35EC: 84 F7        ANDA   #$F7
35EE: B7 10 00     STAA   $1000
35F1: BD 9A 27     JSR    $9A27  ; <<< SUBROUTINE CALL
35F4: F6 10 00     LDAB   $1000
35F7: C4 E7        ANDB   #$E7
35F9: 32           PULA   
35FA: 1B           ABA    
