{
  description = "Script for generating Nixpkgs/NixOS channels";

  inputs.nixpkgs.follows = "nix/nixpkgs";

  outputs = { self, nixpkgs, nix }:

    {

      overlays.default = final: prev: {

        nixos-channel-native-programs = with final; stdenv.mkDerivation {
          name = "nixos-channel-native-programs";
          buildInputs = [
              final.nix
              pkgconfig
              boehmgc
              nlohmann_json
              boost
              sqlite
          ];

          buildCommand = ''
            mkdir -p $out/bin

            cp ${./file-cache.hh} file-cache.hh

            g++ -Os -g ${./generate-programs-index.cc} -Wall -std=c++14 -o $out/bin/generate-programs-index -I . \
              $(pkg-config --cflags nix-main) \
              $(pkg-config --libs nix-main) \
              $(pkg-config --libs nix-expr) \
              $(pkg-config --libs nix-store) \
              -lsqlite3 -lgc

            g++ -Os -g ${./index-debuginfo.cc} -Wall -std=c++14 -o $out/bin/index-debuginfo -I . \
              $(pkg-config --cflags nix-main) \
              $(pkg-config --libs nix-main) \
              $(pkg-config --libs nix-store) \
              -lsqlite3
          '';
        };

        nixos-channel-scripts = with final; stdenv.mkDerivation {
          name = "nixos-channel-scripts";

          buildInputs = with final.perlPackages;
            [ final.nix
              sqlite
              makeWrapper
              perl
              FileSlurp
              LWP
              LWPProtocolHttps
              ListMoreUtils
              DBDSQLite
              NetAmazonS3
              brotli
              jq
              nixos-channel-native-programs
            ];

          buildCommand = ''
            mkdir -p $out/bin

            cp ${./mirror-nixos-branch.pl} $out/bin/mirror-nixos-branch
            wrapProgram $out/bin/mirror-nixos-branch \
              --set PERL5LIB $PERL5LIB \
              --prefix PATH : ${wget}/bin:${git}/bin:${final.nix}/bin:${gnutar}/bin:${xz}/bin:${rsync}/bin:${openssh}/bin:${nixos-channel-native-programs}/bin:$out/bin

            patchShebangs $out/bin
          '';
        };

      };

      defaultPackage.x86_64-linux = (import nixpkgs {
        system = "x86_64-linux";
        overlays = [ nix.overlays.default self.overlays.default ];
      }).nixos-channel-scripts;

    };
}
