# VY v2.09b six word-width review corrections

Status: REVIEW_READY, not blanket XDF approval.

Exact code consumers show six target XDF items are 16-bit words even though the retained definition represented them as 8-bit values. The review patch changes storage width only; address/equation/title remain otherwise untouched.

Addresses:
- 0x4D5E
- 0x705D
- 0x7A29
- 0x74F6
- 0x7526
- 0x7097

Negative controls in the original audit were used to avoid blindly widening adjacent XDF entries. Native TunerPro review and controlled one-field save/readback are still separate gates.