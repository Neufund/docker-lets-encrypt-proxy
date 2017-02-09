#!/bin/sh
set +e
echo "Machine has $(grep processor /proc/cpuinfo | wc -l) cores and $(awk '/MemTotal/ {print $2}' /proc/meminfo) kB RAM."

# This step is very slow, you can cache it by keeping
# /etc/ssl/dhparam.pem mounted as a volume. Re-using
# the dhparam.pem does not hurt security much.
if [ ! -f /etc/ssl/dhparam.pem ]
then
	echo "Generating Diffie-Hellman parameters..."
	echo "This takes about 20 minutes. You can avoid it by mounting a pre-"
	echo "generated pair under \"/etc/ssl/dhparam.pem\"."
	openssl dhparam -out /etc/ssl/dhparam.pem 4096
else
	echo "Using existing Diffie-Hellman parameters."
fi

echo "Generating self-signed fallback certificate..."
openssl req -new -newkey rsa:4096 -days 3650 -nodes -x509 \
	-subj '/CN=sni-support-required-for-valid-ssl' \
	-keyout /etc/ssl/resty-auto-ssl-fallback.key \
	-out /etc/ssl/resty-auto-ssl-fallback.crt

echo "Exempting Cloudflare from rate limiting..."
# See: https://www.cloudflare.com/ips-v4
# See: https://www.cloudflare.com/ips-v6
export RATE_EXEMPT=$(curl https://www.cloudflare.com/ips-v4 https://www.cloudflare.com/ips-v6 | awk '{print $0,"0;"}')

echo "Configuring nginx..."
if [ -z "$DOMAIN" ]; then
	echo "No domain set. Removing Let's Encrypt certification."
	for FILE in /etc/nginx/*.conf
	do
		sed -i '/letsencrypt/d' "$FILE"
	done
	export DOMAIN="$(ip r | awk '/src/{print $5}')"
	echo "You can set a domain name by setting the \$DOMAIN environment"
	echo "variable. Falling back to hostname \"$DOMAIN\"."
fi
if [ -z "$ORIGIN_HOST" ]; then
	echo "You need to provide the upstream hostname in \$ORIGIN_HOST"
	exit 1
fi
if [ -z "$ORIGIN_PORT" ]; then
	export ORIGIN_PORT=80
fi
VARIABLES=" \$DOMAIN \$ORIGIN_HOST \$ORIGIN_PORT \$RATE_EXEMPT"
for FILE in /etc/nginx/*.conf
do
	echo "$FILE"
	envsubst "$VARIABLES" < "$FILE" > "$FILE.tmp"
	mv "$FILE.tmp" "$FILE"
done

echo "Starting nginx..."
echo "Server available at:"
echo ""
echo "     http://${DOMAIN}/"
echo "    https://${DOMAIN}/"
echo ""
exec /usr/local/openresty/bin/openresty -c /etc/nginx/nginx.conf -g "daemon off;"
