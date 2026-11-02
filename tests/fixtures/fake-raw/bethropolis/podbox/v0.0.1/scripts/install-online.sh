#!/bin/sh
# Simulates a corrupted download: the real installer would abort on a checksum mismatch.
echo "checksum mismatch" >&2
exit 1
