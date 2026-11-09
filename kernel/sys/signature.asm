.include "version.inc"

.segment "K_SIGNATURE"

.assert * = $c000, error, "Signature must start at $c000"

kernel_signature: .byt version_major, version_minor, version_patch
