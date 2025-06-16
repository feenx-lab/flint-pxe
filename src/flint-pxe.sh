#!/bin/bash

# Defaults
P_ARGS=()
NETWORK_RANGE="192.168.1.0"
SCHEMATIC_ID="376567988ad370138ad8b2698212367b8edcb69b5fd68c80be1f2ec7d603b4ba"
BASE_URL="https://pxe.factory.talos.dev/pxe"
TALOS_VERSION="1.10.4"
MAC_ADDRESSES=()

help(){
   echo "Usage:"
   echo -e "\tdocker run --rm feenx-lab/flint-pxe [options]"
   echo
   echo "Options:"
   echo -e "\t\t-n,--network-range <network-range>\t\tSpecifies the <start-addr> for dnsmasq's dhcp-range argument"
   echo -e "\t\t-s,--schematic-id <schematic-id>\t\tSchematic ID from Talos Image factory"
   echo -e "\t\t-u,--base-url <base-url>\t\tBase url to get the ipxe script from"
   echo -e "\t\t-v,--talos-version <talos-version>\t\tTalos version number to use"
   echo -e "\t\t-m,--mac-address <mac-address>\t\tMAC address"
   echo
   echo "Examples:"
   echo -e "\t docker run --rm feenx-lab/fint-pxe --network-range 192.168.1.0 --schematic-id 376567988ad370138ad8b2698212367b8edcb69b5fd68c80be1f2ec7d603b4ba --talos-version 1.10.4"
   echo -e "\t docker run --rm feenx-lab/fint-pxe -n 192.168.1.0 --s 376567988ad370138ad8b2698212367b8edcb69b5fd68c80be1f2ec7d603b4ba -v 1.10.4"
}

# Print help if no args are given
if [[ $# -eq 0 ]]; then
   help
   exit 0
fi


# Parse args
while [[ $# -gt 0 ]]; do
  case $1 in
    -n|--network-range)
      if [[ $2 =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        NETWORK_RANGE="$2"
      else
        echo "Invalid IP."
        exit 1
      fi
      shift # skip argument
      shift # skip value
      ;;
    -s|--schematic-id)
      SCHEMATIC_ID="$2"
      shift # skip argument
      shift # skip value
      ;;
    -u|--base-url)
      BASE_URL="$2"
      shift # skip argument
      shift # skip value
      ;;
    -v|--talos-version)
      SANITIZED_VERSION=$(echo $2 | sed 's/^v/')
      if [[ $SANITIZED_VERSION =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
         TALOS_VERSION="$2"
      else
         echo "Invalid talos version number"
         exit 1
      fi
      shift # skip argument
      shift # skip value
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
    -h|-?|--help)
      help
      exit 0
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

for i in "${MAC_ADDRESSES[@]}"; do
  echo "MAC: $i"
done

IPXE_SCRIPT_URL="${BASE_URL}/$SCHEMATIC_ID/v${TALOS_VERSION}/metal-amd64"

/usr/sbin/dnsmasq -d -q \
  --dhcp-range=${NETWORK_RANGE},proxy,255.255.255.0 \
  --enable-tftp --tftp-root=/var/lib/tftpboot \
  --pxe-service=tag:#ipxe,x86PC,"PXE chainload to iPXE",undionly.kpxe \
  --pxe-service=tag:ipxe,x86PC,"iPXE",$IPXE_SCRIPT_URL \
  --pxe-service=tag:#ipxe,X86-64_EFI,"PXE chainload to iPXE UEFI",ipxe.efi \
  --pxe-service=tag:ipxe,X86-64_EFI,"iPXE UEFI",$IPXE_SCRIPT_URL \
  --log-queries \
  --log-dhcp \
  --dhcp-userclass=set:ipxe,iPXE \
  &