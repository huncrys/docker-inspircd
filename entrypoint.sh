#!/bin/sh
# shellcheck disable=SC2068

INSPIRCD_ROOT="/inspircd"

if [ ! -w $INSPIRCD_ROOT/conf/ ]; then
    echo "
        ##################################
        ###                            ###
        ###   Can't write to volume!   ###
        ###    Please change owner     ###
        ###        to uid 10000        ###
        ###                            ###
        ##################################
    "
fi

# Link certificates from secrets
# See https://docs.docker.com/engine/swarm/secrets/
if [ -e /run/secrets/inspircd.key ] && [ -e /run/secrets/inspircd.crt ]; then
    ln -s /run/secrets/inspircd.key $INSPIRCD_ROOT/conf/key.pem
    ln -s /run/secrets/inspircd.crt $INSPIRCD_ROOT/conf/cert.pem
fi

# Make sure there is a certificate or generate a new one
if [ ! -e $INSPIRCD_ROOT/conf/cert.pem ] && [ ! -e $INSPIRCD_ROOT/conf/key.pem ]; then
    cat > /tmp/cert.template <<EOF
cn              = "${INSP_TLS_CN:-irc.example.com}"
email           = "${INSP_TLS_MAIL:-nomail@irc.example.com}"
unit            = "${INSP_TLS_UNIT:-Example Server Admins}"
organization    = "${INSP_TLS_ORG:-Example IRC Network}"
locality        = "${INSP_TLS_LOC:-Example City}"
state           = "${INSP_TLS_STATE:-Example State}"
country         = "${INSP_TLS_COUNTRY:-XZ}"
expiration_days = ${INSP_TLS_DURATION:-365}
tls_www_client
tls_www_server
signing_key
encryption_key
cert_signing_key
crl_signing_key
code_signing_key
ocsp_signing_key
time_stamping_key
EOF
    /usr/bin/certtool --generate-privkey --bits 4096 --sec-param normal --outfile $INSPIRCD_ROOT/conf/key.pem
    /usr/bin/certtool --generate-self-signed --load-privkey $INSPIRCD_ROOT/conf/key.pem --outfile $INSPIRCD_ROOT/conf/cert.pem --template /tmp/cert.template
    rm /tmp/cert.template
fi

# Make sure dhparams are present
if [ ! -e $INSPIRCD_ROOT/conf/dhparams.pem ]; then
    /usr/bin/certtool --generate-dh-params --sec-param normal --outfile $INSPIRCD_ROOT/conf/dhparams.pem
fi

cd $INSPIRCD_ROOT
exec env INSPIRCD_ROOT=$INSPIRCD_ROOT $INSPIRCD_ROOT/bin/inspircd --nofork $@
