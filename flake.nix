{
  description = "feenx-infra";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
      in
      with pkgs;
      {
        devShells.default = mkShell {
          packages = [
            docker
            docker-compose
            neovim
            dnsmasq
            wakeonlan
            ipcalc
            nmap
            traceroute
          ];
        };
      }
    );
}