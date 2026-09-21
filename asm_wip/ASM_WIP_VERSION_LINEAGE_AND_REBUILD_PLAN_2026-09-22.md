# VY $060A ASM WIP version lineage and rebuild plan

## Historical line

The old spark-cut series progressed from original/v2/v3/v4 through v9/v18/v23, v32-v38, The1 v39, BMW-inspired v40, Delco-optimized v41, low-RPM v43, bank-fixed v44 and engine-bank v45.

Useful work recovered along the way:
- bank overlay behavior;
- common-area vs same-bank call placement;
- exact hook bytes;
- dwell/reference variables;
- test scaffolds;
- hysteresis/state-machine ideas.

The invalid assumption was treating dwell/reference-history perturbation itself as final ignition-output proof.

## New launch line

factory v1.0a -> R07b concept/user feedback -> R08 exact-target factory limiter/FUELCTOF selector -> R09 PWR-gated selector -> optional range/TPS/brake/clutch qualification.

Do not mix R08 with the v1.1a spark beta.

## Shared-service target

Feature files should converge on:

factory inputs/state -> feature state machine -> request object -> shared low-level service -> diagnostic state -> timeout/failsafe -> clean release to factory.

Example conceptual requests:
CUT_REQUEST, FUEL_CUT_REQUEST, SPARK_RETARD_REQUEST, ALT_LIMITER_REQUEST, ALT_TABLE_REQUEST, IDLE_MODE_REQUEST, BOOST_DUTY_REQUEST.

## Exact identity contract

Every active patch package should record:
- exact input SHA-256 and size;
- expected original bytes;
- file/CPU/bank mapping;
- patch and reverse bytes;
- changed-offset allow-list;
- checksum state;
- output hash;
- verifier hash/version.

## RAM ownership contract

No scratch RAM by assumption. Record address, size, producers, consumers, ISR/main ownership, startup init, diagnostic exposure, sibling bits and reuse status.

## Bank/call contract

Record hook file offset, CPU address, active bank/context, original/replacement instruction, callee visibility, register preservation, stack delta and return contract.

## Feature migration

- launch: R08/R09;
- NLS/flat shift: detector -> shared request;
- rolling limiter: state/hysteresis -> shared request;
- ghost: factory retarded idle first, scheduler modulation later;
- MAFless: factory default-airflow path;
- speed density: separate MAP/load project;
- E85/multi-map: prove factory PWR selector first;
- boost: prove sensor/output/failsafe as its own subsystem.

A higher historical version number is not evidence. Use evidence grade, not filename revision.

A rebuilt semantic v1 should have exact identity, no guessed RAM, documented selector/state, shared service, deterministic builder/verifier, reverse path, diagnostic observability, timeout/failsafe and bench plan.