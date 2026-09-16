#!/bin/sh
# Legacy entry retained only to give old bookmarks a safe migration message.
set -eu

cat >&2 <<'EOF'
setup.sh has been retired in v4.0.0.
This project now supports OpenWrt-family routers only and installs from a complete, checksummed GitHub Release.
Download ruijie-core-4.0.0.tar.gz and SHA256SUMS from:
https://github.com/huantuoshen-prog/ruijie-gdstvc-autologin/releases/tag/v4.0.0
Then follow docs/install.md. No files were changed and no network authentication action was attempted.
EOF
exit 2
