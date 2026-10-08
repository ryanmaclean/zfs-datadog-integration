#!/bin/sh
# Legacy Packer wrapper writes relative logs and VM images without off-NAS storage provenance.
printf '%s\n' 'HOLD (78): build-all-images requires a verified disposable off-NAS build and output root.' >&2
exit 78
