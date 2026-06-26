#!/bin/bash
set -euo pipefail
 
echo "=== CIS Level 1 Hardening — RHEL 9 ==="
 
# ── 1. Filesystem Configuration ──────────────────────────────
echo "[1] Configuring filesystem mount options..."
 
for fs in cramfs freevxfs jffs2 hfs hfsplus squashfs udf; do
  echo "install $fs /bin/true" >> /etc/modprobe.d/disabled-filesystems.conf
done
 
# ── 2. SELinux Enforcement ───────────────────────────────────
# SELinux is RHEL mandatory access control. CIS Level 1 requires enforcing mode.
# Ubuntu uses AppArmor instead — this is the most significant OS-level difference.
echo "[2] Configuring SELinux..."
 
sed -i 's/^SELINUX=.*/SELINUX=enforcing/' /etc/selinux/config
sed -i 's/^SELINUXTYPE=.*/SELINUXTYPE=targeted/' /etc/selinux/config
setenforce 1 2>/dev/null || true
 
# ── 3. SSH Hardening ─────────────────────────────────────────
echo "[3] Hardening SSH configuration..."
 
cat > /etc/ssh/sshd_config.d/cis-hardening.conf << 'SSHEOF'
Protocol 2
LogLevel VERBOSE
LoginGraceTime 60
PermitRootLogin no
MaxAuthTries 4
PubkeyAuthentication yes
PasswordAuthentication no
PermitEmptyPasswords no
AllowAgentForwarding no
AllowTcpForwarding no
X11Forwarding no
ClientAliveInterval 15
ClientAliveCountMax 3
Banner /etc/issue.net
SSHEOF
 
sshd -t
 
# ── 4. Password Policy ───────────────────────────────────────
echo "[4] Configuring password policy..."
 
sed -i 's/^PASS_MAX_DAYS.*/PASS_MAX_DAYS   365/' /etc/login.defs
sed -i 's/^PASS_MIN_DAYS.*/PASS_MIN_DAYS   1/'   /etc/login.defs
sed -i 's/^PASS_WARN_AGE.*/PASS_WARN_AGE   7/'   /etc/login.defs
 
dnf install -y libpwquality
 
cat > /etc/security/pwquality.conf << 'PWEOF'
minlen = 14
minclass = 4
dcredit = -1
ucredit = -1
ocredit = -1
lcredit = -1
PWEOF
 
# ── 5. Audit Logging ─────────────────────────────────────────
echo "[5] Configuring auditd..."
 
dnf install -y audit
 
cat > /etc/audit/rules.d/cis.rules << 'AUDITEOF'
-D
-b 8192
-w /etc/passwd  -p wa -k identity
-w /etc/shadow  -p wa -k identity
-w /etc/sudoers -p wa -k sudoers
-w /etc/ssh/sshd_config -p wa -k sshd
-w /etc/selinux/ -p wa -k selinux
-a always,exit -F arch=b64 -S execve -C uid!=euid -F euid=0 -k setuid
AUDITEOF
 
systemctl enable --now auditd
 
# ── 6. Firewalld ─────────────────────────────────────────────
# RHEL 9 uses firewalld. CIS requires a host-based firewall to be active.
echo "[6] Configuring firewalld..."
 
dnf install -y firewalld
systemctl enable --now firewalld
firewall-cmd --set-default-zone=drop
firewall-cmd --permanent --zone=drop --add-service=ssh
firewall-cmd --reload
 
# ── 7. Network Hardening ─────────────────────────────────────
echo "[7] Hardening network settings..."
 
cat > /etc/sysctl.d/99-cis-hardening.conf << 'SYSCTLEOF'
net.ipv4.ip_forward = 0
net.ipv4.tcp_syncookies = 1
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.all.log_martians = 1
net.ipv6.conf.all.disable_ipv6 = 1
SYSCTLEOF
 
sysctl -p /etc/sysctl.d/99-cis-hardening.conf
 
# ── 8. Disable Unnecessary Services ─────────────────────────
echo "[8] Disabling unnecessary services..."
 
for svc in avahi-daemon cups dhcpd slapd nfs-server rpcbind named vsftpd httpd dovecot smb squid snmpd; do
  systemctl disable "$svc" 2>/dev/null || true
  systemctl stop    "$svc" 2>/dev/null || true
done
 
# ── 9. Login Banner ──────────────────────────────────────────
echo "[9] Setting login banner..."
 
cat > /etc/issue.net << 'BANNEREOF'
AUTHORIZED USE ONLY. Unauthorized access is prohibited and will be prosecuted.
All activity is monitored and logged.
BANNEREOF
 
cp /etc/issue.net /etc/issue
 
echo "=== CIS hardening complete ==="
