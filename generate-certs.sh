if test "x$1x" == "xx"; then
  FQDN="localhost"
else
  FQDN=$1
fi

openssl req -x509 -sha256 -nodes -days 365 -newkey rsa:2048 -keyout haproxy.key -out haproxy.crt -subj "/C=FI/O=Intel SSP/CN=${FQDN}"
cat haproxy.crt haproxy.key > haproxy.pem
