#!/bin/bash
# ============================================================================
# One-shot bootstrap for RStudio Server inside the
# koalalive/cmdstanr4cogneuro:1.0.1 image.
#
# The image ships RStudio Server 2026.01 but a few runtime pieces are missing
# or misconfigured (no conda libs visible to rsession, no PAM config for
# RStudio, no login password, missing home directory). This script patches
# them inside the container and then keeps RStudio Server running in the
# foreground (use `docker run -d`).
#
# Usage (see README.md):
#   docker run -d -p 8787:8787 -e RS_PASSWORD=your_password \
#     -v "$(pwd)":/workspace -w /workspace \
#     koalalive/cmdstanr4cogneuro:1.0.1 bash _scripts/start_rstudio.sh
#
# Log in with username: rstudio-server , password: $RS_PASSWORD (default: rstudio)
# ============================================================================
set -u

echo "[1/5] Patching R libraries so rsession can find R (conda libs -> system dirs)..."
mkdir -p /usr/lib/x86_64-linux-gnu
cp -an /root/miniconda3/envs/stan/lib/R/lib/*.so* /usr/lib/x86_64-linux-gnu/ >/dev/null 2>&1 || true
cp -an /root/miniconda3/envs/stan/lib/*.so*    /usr/lib/x86_64-linux-gnu/ >/dev/null 2>&1 || true
ldconfig >/dev/null 2>&1 || true

echo "[2/5] Ensuring rstudio-server home directory exists..."
mkdir -p /home/rstudio-server
chown rstudio-server:rstudio-server /home/rstudio-server

echo "[3/5] Setting login password (user rstudio-server, password: ${RS_PASSWORD:-rstudio})..."
echo "rstudio-server:${RS_PASSWORD:-rstudio}" | chpasswd

echo "[4/5] Writing PAM config and switching to PAM login..."
printf 'auth required pam_unix.so\nauth required pam_nologin.so\n' \
       'account required pam_unix.so\n' \
       'session required pam_unix.so\n' \
       'session optional pam_limits.so\n' > /etc/pam.d/rstudio
cp -n /etc/pam.d/rstudio /etc/pam.d/rstudio-server 2>/dev/null || true
sed -i 's/^auth-none=1/#auth-none=1 (PAM login enabled)/' /etc/rstudio/rserver.conf

echo "[5/5] Starting RStudio Server on 0.0.0.0:8787 ..."
export PATH=/root/miniconda3/envs/stan/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
exec /usr/lib/rstudio-server/bin/rserver \
  --server-daemonize 0 \
  --server-user rstudio-server \
  --www-port 8787 \
  --www-address 0.0.0.0
