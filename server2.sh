#!/bin/bash

#use screen -S f
#screen -r f
#CTRL+A+D


#Debian Ubuntu
#Debian >= 10
#Ubuntu >= 16.04


#IP Server 1
IPSERVER1="111.111.111.111"


source /etc/os-release

#OS="debian"
OS=$ID

# DELETE

if [[ -e /etc/openvpn/server.conf ]]; then

	# Get OpenVPN port from the configuration
	#PORT=$(grep '^port ' /etc/openvpn/server.conf | cut -d " " -f 2)
	#PROTOCOL=$(grep '^proto ' /etc/openvpn/server.conf | cut -d " " -f 2)


	if [[ $OS == "ubuntu" ]] && [[ $VERSION_ID == "16.04" ]]; then
		systemctl disable openvpn
		systemctl stop openvpn
	else
		systemctl disable openvpn@server
		systemctl stop openvpn@server
		# Remove customised service
		rm /etc/systemd/system/openvpn\@.service
	fi

	# Remove the iptables rules related to the script
	systemctl stop iptables-openvpn
	# Cleanup
	systemctl disable iptables-openvpn
	rm /etc/systemd/system/iptables-openvpn.service
	systemctl daemon-reload
	rm /etc/iptables/add-openvpn-rules.sh
	rm /etc/iptables/rm-openvpn-rules.sh



		apt-get remove --purge -y openvpn
		if [[ -e /etc/apt/sources.list.d/openvpn.list ]]; then
			rm /etc/apt/sources.list.d/openvpn.list
			apt-get update
		fi


	# Cleanup
	find /home/ -maxdepth 2 -name "*.ovpn" -delete
	find /root/ -maxdepth 1 -name "*.ovpn" -delete
	rm -rf /etc/openvpn
	rm -rf /usr/share/doc/openvpn*
	rm -f /etc/sysctl.d/99-openvpn.conf
	rm -rf /var/log/openvpn

	echo ""
	echo "OpenVPN removed!"

fi

# INSTALL

apt-get update
apt-get -y install ca-certificates gnupg

# We add the OpenVPN repo to get the latest version.
if [[ $OS == "ubuntu" ]] && [[ $VERSION_ID == "16.04" ]]; then
  echo "deb http://build.openvpn.net/debian/openvpn/stable xenial main" >/etc/apt/sources.list.d/openvpn.list
  wget -O - https://swupdate.openvpn.net/repos/repo-public.gpg | apt-key add -
  apt-get update
fi

apt-get install -y openvpn iptables openssl wget ca-certificates curl

if [[ -d /etc/openvpn/easy-rsa/ ]]; then
  rm -rf /etc/openvpn/easy-rsa/
fi

if grep -qs "^nogroup:" /etc/group; then
	NOGROUP=nogroup
else
	NOGROUP=nobody
fi

wget -O ~/easy-rsa.tgz https://github.com/OpenVPN/easy-rsa/releases/download/v3.0.7/EasyRSA-3.0.7.tgz
mkdir -p /etc/openvpn/easy-rsa
tar xzf ~/easy-rsa.tgz --strip-components=1 --directory /etc/openvpn/easy-rsa
rm -f ~/easy-rsa.tgz

cd /etc/openvpn/easy-rsa/ || return

echo "set_var EASYRSA_KEY_SIZE 4096" >vars

SERVER_CN="cn_$(head /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 16 | head -n 1)"
echo "$SERVER_CN" >SERVER_CN_GENERATED
SERVER_NAME="server_$(head /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 16 | head -n 1)"
echo "$SERVER_NAME" >SERVER_NAME_GENERATED

echo "set_var EASYRSA_REQ_CN $SERVER_CN" >>vars

./easyrsa init-pki
./easyrsa --batch build-ca nopass

openssl dhparam -out dh.pem 4096

./easyrsa build-server-full "$SERVER_NAME" nopass
EASYRSA_CRL_DAYS=3650 ./easyrsa gen-crl

openvpn --genkey --secret /etc/openvpn/tls-auth.key

cp pki/ca.crt pki/private/ca.key "pki/issued/$SERVER_NAME.crt" "pki/private/$SERVER_NAME.key" /etc/openvpn/easy-rsa/pki/crl.pem /etc/openvpn
cp dh.pem /etc/openvpn

chmod 644 /etc/openvpn/crl.pem

echo "port 443" >/etc/openvpn/server.conf
echo "proto tcp" >>/etc/openvpn/server.conf

echo "dev tun
user nobody
group $NOGROUP
persist-key
persist-tun
keepalive 10 120
topology subnet
server 10.10.0.0 255.255.255.0
ifconfig-pool-persist ipp.txt" >>/etc/openvpn/server.conf

echo 'push "route 10.10.0.0 255.255.255.0"' >>/etc/openvpn/server.conf

# OpenDNS
echo 'push "dhcp-option DNS 208.67.222.222"' >>/etc/openvpn/server.conf
echo 'push "dhcp-option DNS 208.67.220.220"' >>/etc/openvpn/server.conf

# Cloudflare
#echo 'push "dhcp-option DNS 1.0.0.1"' >>/etc/openvpn/server.conf
#echo 'push "dhcp-option DNS 1.1.1.1"' >>/etc/openvpn/server.conf

# Google
#echo 'push "dhcp-option DNS 8.8.8.8"' >>/etc/openvpn/server.conf
#echo 'push "dhcp-option DNS 8.8.4.4"' >>/etc/openvpn/server.conf

#echo 'push "redirect-gateway def1 bypass-dhcp"' >>/etc/openvpn/server.conf
echo "dh dh.pem" >>/etc/openvpn/server.conf

echo "tls-auth tls-auth.key 0" >>/etc/openvpn/server.conf

echo "crl-verify crl.pem
ca ca.crt
cert $SERVER_NAME.crt
key $SERVER_NAME.key
auth SHA512
cipher AES-256-CBC
ncp-ciphers AES-256-CBC
tls-server
tls-version-min 1.2
tls-cipher TLS-ECDHE-RSA-WITH-AES-256-GCM-SHA384
client-config-dir /etc/openvpn/ccd
#status /var/log/openvpn/status.log
#verb 3
duplicate-cn
log /dev/null
log-append /dev/null
status /dev/null
verb 0" >>/etc/openvpn/server.conf


mkdir -p /etc/openvpn/ccd
mkdir -p /var/log/openvpn

echo 'net.ipv4.ip_forward=1' >/etc/sysctl.d/99-openvpn.conf

sysctl --system


if [[ $OS == "ubuntu" ]] && [[ $VERSION_ID == "16.04" ]]; then
	# On Ubuntu 16.04, we use the package from the OpenVPN repo
	# This package uses a sysvinit service
	systemctl enable openvpn
	systemctl start openvpn
else

	# Don't modify package-provided service
	cp /lib/systemd/system/openvpn\@.service /etc/systemd/system/openvpn\@.service

	# Workaround to fix OpenVPN service on OpenVZ
	sed -i 's|LimitNPROC|#LimitNPROC|' /etc/systemd/system/openvpn\@.service
	# Another workaround to keep using /etc/openvpn/
	sed -i 's|/etc/openvpn/server|/etc/openvpn|' /etc/systemd/system/openvpn\@.service

	systemctl daemon-reload
	systemctl enable openvpn@server
	systemctl restart openvpn@server
fi


mkdir -p /etc/iptables

NIC=$(ip -4 route ls | grep default | grep -Po '(?<=dev )(\S+)' | head -1)


echo "#!/bin/sh
iptables -t nat -I POSTROUTING 1 -s 10.10.0.0/24 -o $NIC -j MASQUERADE
iptables -I INPUT 1 -i tun0 -j ACCEPT
iptables -I FORWARD 1 -i $NIC -o tun0 -j ACCEPT
iptables -I FORWARD 1 -i tun0 -o $NIC -j ACCEPT
iptables -I INPUT 1 -i $NIC -p tcp --dport 443 -j ACCEPT
ip6tables -I INPUT 1 -j DROP
ip6tables -I FORWARD 1 -j DROP
ip6tables -I OUTPUT 1 -j DROP" >/etc/iptables/add-openvpn-rules.sh


#ipv6 block
#...

echo "#!/bin/sh
iptables -t nat -D POSTROUTING -s 10.10.0.0/24 -o $NIC -j MASQUERADE
iptables -D INPUT -i tun0 -j ACCEPT
iptables -D FORWARD -i $NIC -o tun0 -j ACCEPT
iptables -D FORWARD -i tun0 -o $NIC -j ACCEPT
iptables -D INPUT -i $NIC -p tcp --dport 443 -j ACCEPT
ip6tables -D INPUT -j DROP
ip6tables -D FORWARD -j DROP
ip6tables -D OUTPUT -j DROP" >/etc/iptables/rm-openvpn-rules.sh


chmod +x /etc/iptables/add-openvpn-rules.sh
chmod +x /etc/iptables/rm-openvpn-rules.sh

echo "[Unit]
Description=iptables rules for OpenVPN
Before=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=/etc/iptables/add-openvpn-rules.sh
ExecStop=/etc/iptables/rm-openvpn-rules.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target" >/etc/systemd/system/iptables-openvpn.service


systemctl daemon-reload
systemctl enable iptables-openvpn
systemctl start iptables-openvpn

IP=$(ip -4 addr | sed -ne 's|^.* inet \([^/]*\)/.* scope global.*$|\1|p' | head -1)


echo "client" >/etc/openvpn/client-template.txt
echo "proto tcp-client" >>/etc/openvpn/client-template.txt

echo "remote $IP 443
dev tun1
resolv-retry infinite
nobind
persist-key
persist-tun
remote-cert-tls server
verify-x509-name $SERVER_NAME name
auth SHA512
auth-nocache
cipher AES-256-CBC
tls-client
tls-version-min 1.2
tls-cipher TLS-ECDHE-RSA-WITH-AES-256-GCM-SHA384
ignore-unknown-option block-outside-dns
#setenv opt block-outside-dns # Prevent Windows 10 DNS leak
verb 3
script-security 2
up /etc/openvpn/upstream-route.sh" >>/etc/openvpn/client-template.txt


cd /etc/openvpn/easy-rsa/ || return
./easyrsa build-client-full "client000" nopass

if [ -e "/home/client000" ]; then
	# if $1 is a user name
	homeDir="/home/client000"
elif [ "${SUDO_USER}" ]; then
	# if not, use SUDO_USER
	if [ "${SUDO_USER}" == "root" ]; then
		# If running sudo as root
		homeDir="/root"
	else
		homeDir="/home/${SUDO_USER}"
	fi
else
	# if not SUDO_USER, use /root
	homeDir="/root"
fi


cp /etc/openvpn/client-template.txt "$homeDir/client000.ovpn"

{
	echo "<ca>"
	cat "/etc/openvpn/easy-rsa/pki/ca.crt"
	echo "</ca>"

	echo "<cert>"
	#awk '/BEGIN/,/END/' "/etc/openvpn/easy-rsa/pki/issued/client000.crt"
	awk '/---BEGIN/,/---END/' "/etc/openvpn/easy-rsa/pki/issued/client000.crt"
	echo "</cert>"

	echo "<key>"
	cat "/etc/openvpn/easy-rsa/pki/private/client000.key"
	echo "</key>"

	echo "key-direction 1"
	echo "<tls-auth>"
	cat /etc/openvpn/tls-auth.key
	echo "</tls-auth>"
} >>"$homeDir/client000.ovpn"



#echo "Enter password for Server 1"
#ssh root@$IPSERVER1 'mkdir -p /etc/openvpn'

echo "Enter password for Server 1"
scp /root/client000.ovpn root@$IPSERVER1:/etc/openvpn/client.conf

echo "Enter password for Server 1"
ssh root@$IPSERVER1 'systemctl enable openvpn@client'
echo "Enter password for Server 1"
ssh root@$IPSERVER1 'systemctl start openvpn@client'


#reboot
echo ""
echo ""
echo "Готово! Ребутни сервак! reboot"







