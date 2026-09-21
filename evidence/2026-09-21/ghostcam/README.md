# Ghost-cam / retarded-idle semantic audit

Status: STATIC_CANDIDATE_DO_NOT_FLASH.

Exact findings used by the repair matrix:

- retained ghost selector source SHA-256: c76def1f2e6fa7af38e28f4331c561c840371b5cc201afc9c038b28c8769f017
- ENGINE_EVENT_COUNTER at $1916 is semantically wrong for periodic modulation
- exact target code shows $1916 is conditionally incremented and consumed by the DTC49 cam/crank diagnostic path
- the selector reads the counter; it does not corrupt it
- normal and retarded idle-value paths remain useful research anchors
- exact reference BIN has equal normal/retarded table bytes and retarded-idle enable clear, so the reference selector has no value difference to alternate
- the stock retarded-idle ramp sits downstream and can heavily attenuate rapid target alternation
- XDF item $6529 is better described as an actual-RPM floor on the underspeed correction branch, not an RPM-error magnitude limit

Next design:
1. vehicle-test the factory retarded-idle calibration path first;
2. use a separately proved periodic scheduler/event source;
3. specify modulation position relative to the stock ramp;
4. keep diagnostic counters untouched.