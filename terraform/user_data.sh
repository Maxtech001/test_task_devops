
#!/bin/bash
set -euxo pipefail

# format and mount additional volumes if first boot (idempotent check)
if ! lsblk | grep -q xvdb; then
  echo "No xvdb found"; fi
if ! blkid /dev/xvdb >/dev/null 2>&1; then
  mkfs.xfs /dev/xvdb
fi
mkdir -p /data1
grep -q '/dev/xvdb' /etc/fstab || echo '/dev/xvdb /data1 xfs defaults,nofail 0 2' >> /etc/fstab
mount -a

if ! blkid /dev/xvdc >/dev/null 2>&1; then
  mkfs.xfs /dev/xvdc
fi
mkdir -p /data2
grep -q '/dev/xvdc' /etc/fstab || echo '/dev/xvdc /data2 xfs defaults,nofail 0 2' >> /etc/fstab
mount -a

# simple hello world web page
cat >/usr/share/hello.html <<'EOF'
<!doctype html>
<html><head><title>Hello</title></head>
<body><h1>Hello from EC2</h1></body></html>
EOF

# start a tiny web server on port 80 using busybox httpd
yum -y install busybox || true
busybox httpd -f -p 0.0.0.0:80 -h /usr/share &
