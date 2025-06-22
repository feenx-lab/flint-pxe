#!/bin/bash

# Defaults
P_ARGS=()
ARCH="amd64"
BASE_URL="https://pxe.factory.talos.dev/pxe"
DHCP_SERVER=""
MAC_ADDRESSES=()
IPXE_URL_OVERRIDE=""
SCHEMATIC_ID="376567988ad370138ad8b2698212367b8edcb69b5fd68c80be1f2ec7d603b4ba"
TEST_MODE=false
TALOS_VERSION="1.10.4"
PLATFORM="metal"
WAIT_TIME=-1

help(){
   echo "Usage:"
   echo -e "\tdocker run --rm feenx-lab/flint-pxe --schematid-id [options]"
   echo
   echo "Options:"
   echo -e "\t\t-a,--arch <amd64|arm64>\t\tArchitecture to use from the Image Factory"
   echo -e "\t\t-b,--base-url <base-url>\t\tBase url to get the ipxe script from"
   echo -e "\t\t-d,--dhcp-server <cidr-dhcp-server-ip>\t\tSpecifies the upstream dhcp server IP address using CIDR notation"
   echo -e "\t\t-h,--help\t\tPrints help message"
   echo -e "\t\t-m,--mac-address <mac-address>\t\tMAC address to wake on lan, can be used multiple times"
   echo -e "\t\t-o,--ipxe-url-override <ipxe-script-url>\t\tOverride the full url for the iPXE script."
   echo -e "\t\t-s,--schematic-id <schematic-id>\t\tSchematic ID from Talos Image factory"
   echo -e "\t\t-t,--test\t\tEnables test mode, basically dry-runs the script"
   echo -e "\t\t-v,--talos-version <talos-version>\t\tTalos version number to use"
   echo -e "\t\t-w,--wait <number-of-seconds>\t\tRun as daemon and wait for number-of-seconds before terminating dnsmasq"
   echo
   echo "Examples:"
   echo -e "\t docker run -it --rm ghcr.io/feenx-lab/fint-pxe"
   echo -e "\t docker run -it --rm ghcr.io/feenx-lab/fint-pxe --schematic-id 376567988ad370138ad8b2698212367b8edcb69b5fd68c80be1f2ec7d603b4ba"
   echo -e "\t docker run -it --rm ghcr.io/feenx-lab/fint-pxe --dhcp-server 192.168.1.1/24 --schematic-id 376567988ad370138ad8b2698212367b8edcb69b5fd68c80be1f2ec7d603b4ba --talos-version 1.10.4"
   echo -e "\t docker run -it --rm ghcr.io/feenx-lab/fint-pxe -d 192.168.1.1/24 --s 376567988ad370138ad8b2698212367b8edcb69b5fd68c80be1f2ec7d603b4ba -v 1.10.4"
}

# Print help if no args are given
if [[ $# -eq 0 ]]; then
   help
   exit 0
fi

# Parse args
while [[ $# -gt 0 ]]; do
  case $1 in
    -a|--arch)
      ARCH=$2
      shift # skip argument
      shift # skip value
      ;;
    -b|--base-url)
      BASE_URL="$2"
      shift # skip argument
      shift # skip value
      ;;
    -d|--dhcp-server)
      if ipcalc -cs $2; then
        DHCP_SERVER=$2
      else
        echo "Invalid IP."
        exit 1
      fi
      shift # skip argument
      shift # skip value
      ;;
    -h|--help)
      help
      exit 0
      ;;
    -m|--mac-address)
      if [[ "$2" =~ ^([0-9A-Fa-f]{2}[:-]){5}([0-9A-Fa-f]{2})$ ]]; then
        MAC_ADDRESSES+=("$2")
      else
        echo "Invalid MAC address $2"
        exit 1
      fi
      shift # skip argument
      shift # skip value
      ;;
    -o|--url-override)
      IPXE_URL_OVERRIDE=$2
      shift # skip argument
      shift # skip value
      ;;
    -s|--schematic-id)
      SCHEMATIC_ID="$2"
      shift # skip argument
      shift # skip value
      ;;
    -t|--test)
      TEST_MODE=true
      shift # skip argument
      ;;
    -v|--talos-version)
      SANITIZED_VERSION=$(echo $2 | sed 's/^v//')
      if [[ $SANITIZED_VERSION =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
         TALOS_VERSION="$SANITIZED_VERSION"
      else
         echo "Invalid talos version number"
         exit 1
      fi
      shift # skip argument
      shift # skip value
      ;;
    -w|--wait)
      if [[ $2 =~ ^[0-9]+$ ]]; then
        WAIT_TIME=$2
      else
        echo "Invalid wait time, only specify number of seconds"
        exit 1
      fi
      shift # skip argument
      shift # skip value
      ;;
    -*|--*)
      echo "Unknown option $1"
      exit 1
      ;;
    *)
      P_ARGS+=("$1") # save positional arg
      shift # skip argument
      ;;
  esac
done

# Reset positional args
set -- "${P_ARGS[@]}"

if [[ -z "$DHCP_SERVER" ]]; then
  echo "Error: No DHCP server specified"
  exit 1
fi

# Split up the dhcp server IP and netmask
DHCP_SERVER_IP=$(ipcalc $DHCP_SERVER | grep Address: | awk '{print $2}')
NETMASK=$(ipcalc $DHCP_SERVER | grep Netmask | sed 's/ =.*//' | awk '{print $2}')

# Send magic packtes to given mac addresses
for m in "${MAC_ADDRESSES[@]}"; do
  awake $m
done

IPXE_SCRIPT_URL="${BASE_URL}/$SCHEMATIC_ID/v${TALOS_VERSION}/${PLATFORM}-${ARCH}"

if [[ -n "$IPXE_URL_OVERRIDE" ]]; then
  IPXE_SCRIPT_URL="${IPXE_URL_OVERRIDE}"
fi

command=$(cat << EOF
/usr/sbin/dnsmasq -d -q
  --port=0
  --dhcp-range=${DHCP_SERVER_IP},proxy,${NETMASK}
  --enable-tftp --tftp-root=/var/lib/tftpboot
  --dhcp-userclass=set:ipxe,iPXE
  --pxe-service=tag:#ipxe,x86PC,"PXE chainload to iPXE",undionly.kpxe
  --pxe-service=tag:ipxe,x86PC,"iPXE",$IPXE_SCRIPT_URL
  --pxe-service=tag:#ipxe,X86-64_EFI,"PXE chainload to iPXE UEFI",ipxe.efi
  --pxe-service=tag:ipxe,X86-64_EFI,"iPXE UEFI",$IPXE_SCRIPT_URL
  --log-queries
  --log-dhcp
EOF
)

if [[ "${TEST_MODE}" = true ]]; then
  echo "$command"
elif [[ $WAIT_TIME -ge 0 ]]; then
  eval $command &
  DAEMON_PID=$!
  sleep $WAIT_TIME
  if kill -0 "$DAEMON_PID" 2>/dev/null; then
    echo "Daemon still running, killing it..."
    kill "$DAEMON_PID"
  fi
else
  eval $command
fi