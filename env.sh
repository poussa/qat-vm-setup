export PATH=/usr/local/ssl/bin:/usr/local/bin:$PATH
export LD_LIBRARY_PATH=/usr/local/ssl/lib:$LD_LIBRARY_PATH
export OPENSSL_ENGINES=/usr/local/ssl/lib/engines-1.1

function _qat_ls_pf() {
  for i in 0434 0435 37c8 1f18 1f19; do lspci -d 8086:$i; done
}

function _qat_ls_vf() {
  for i in 0442 0443 37c9 19e3; do lspci -d 8086:$i; done
}

function _qat_openssl_engine_test() {
  openssl engine -c -t qat
}

function _qat_setup_dev_permissions() {
  sudo chgrp haproxy /dev/qat_*
  sudo chgrp haproxy /dev/usdm_drv
  sudo chgrp haproxy /dev/uio*
}

function _qat_create_certs() {
  FQDN=$(hostname)
  openssl req -x509 -sha256 -nodes -days 365 -newkey rsa:2048 -keyout haproxy.key -out haproxy.crt -subj "/C=FI/O=Intel SSP/CN=${FQDN}"
  cat haproxy.crt haproxy.key > haproxy.pem
}

function _qat_counters() {
  sudo cat /sys/kernel/debug/qat_c6xx_0000\:3d\:00.0/fw_counters
}
