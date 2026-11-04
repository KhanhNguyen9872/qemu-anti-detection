#!/usr/bin/env bash
# Safe Exam Browser profile: TCG (no KVM hypercall interception) and no TPM
# (no OVMF measured-boot log).  Much slower than the default KVM profile.
set -e
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export ACCEL=tcg
export TPM=0
export DISK="${DISK:-$DIR/win10.qcow2}"
export VARS="${VARS:-$DIR/win10_VARS.fd}"
exec "$DIR/start-win10.sh" "$@"
