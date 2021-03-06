#!/usr/bin/with-contenv sh

# Settings

pia_client_id_file=/config/openvpn/pia_client_id
transmission_settings_file=${TRANSMISSION_HOME}/settings.json

#
# First get a port from PIA
#

new_client_id() {
    head -n 100 /dev/urandom | sha256sum | tr -d " -" | tee ${pia_client_id_file}
}

pia_client_id="$(cat ${pia_client_id_file} 2>/dev/null)"
if [[ -z "${pia_client_id}" ]]; then
    echo "Generating new client id for PIA"
    pia_client_id=$(new_client_id)
fi

# Get the port
port_assignment_url="http://209.222.18.222:2000/?client_id=$pia_client_id"
pia_response=$(curl -s -f "$port_assignment_url")
pia_curl_exit_code=$?

# error 52 is empty response, probably happens when Port forwarding is already enabled
# so it is tolerated here
if [[ -z "$pia_response" ]]; then
    echo "Port forwarding is already activated on this connection, has expired, or you are not connected to a PIA region that supports port forwarding"
    exit 0
fi

# Check for curl error (curl will fail on HTTP errors with -f flag)
if [[ ${pia_curl_exit_code} -ne 0 ]]; then
    echo "curl encountered an error looking up new port: $pia_curl_exit_code"
    exit
fi

# Check for errors in PIA response
error=$(echo "$pia_response" | grep -oE "\"error\".*\"")
if [[ ! -z "$error" ]]; then
    echo "PIA returned an error: $error"
    exit
fi

# Get new port, check if empty
new_port=$(echo "$pia_response" | grep -oE "[0-9]+")
if [[ -z "$new_port" ]]; then
    echo "Could not find new port from PIA"
    exit
fi
echo "Got new port $new_port from PIA"

/usr/sbin/set_qbittorrent_port_forwarding.sh "${new_port}"
