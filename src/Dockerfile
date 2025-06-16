# Build iPXE from source
FROM alpine:latest AS ipxe-build

RUN apk add --no-cache mtools libc6-compat gcc make perl xz-dev git musl-dev sed

WORKDIR /repo/
RUN git clone https://github.com/ipxe/ipxe.git .

# Enable HTTPS support in the config
RUN sed -i 's/#undef\tDOWNLOAD_PROTO_HTTPS/#define\tDOWNLOAD_PROTO_HTTPS/' src/config/general.h

RUN make -j 4 -C src bin/undionly.kpxe
RUN make -j 4 -C src bin-x86_64-efi/ipxe.efi

# flint-pxe
FROM docker.io/alpine:3.22.0 AS flint-pxe

COPY flint-pxe.sh /flint-pxe.sh
RUN chmod +x /flint-pxe.sh

# Install dependencies
WORKDIR /var/lib/tftpboot
RUN apk --no-cache add dnsmasq bash && rm -rf /var/cache/apk/*

# Pre-load ipxe bootloader from ipxe-build
COPY --from=ipxe-build /repo/src/bin/undionly.kpxe .
COPY --from=ipxe-build /repo/src/bin-x86_64-efi/ipxe.efi .

#TODO: Variables for the dhcp range for the proxy + netmask
#TODO: Variables for the factory schematic ID or the whole url.
#TODO: Make this a docker run command and not a compose, so that it can be run like a task very easily. (See README.md)
EXPOSE 53 67 69
ENTRYPOINT [ "/flint-pxe.sh"]