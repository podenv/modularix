{
  description = "polyglot";

  inputs = { nixpkgs.url = "github:NixOS/nixpkgs"; };

  outputs = { self, nixpkgs }:
    let
      pkgs = import nixpkgs {
        localSystem = "x86_64-linux";
        config.allowUnfree = true;
      };

      vcv = pkgs.stdenv.mkDerivation rec {
        pname = "Rack";
        version = "2.0.6";
        src = pkgs.fetchurl {
          url = "https://vcvrack.com/downloads/RackFree-${version}-lin.zip";
          sha256 = "sha256-0AZFQ2C7OazRpbmSPKppCxRWKj3JeTkSWSaUcE4bMo8=";
        };
        # This should patchelf to fix nixpkgs libs, but that currently does not work:
        # glwf fails to create the display.
        # nativeBuildInputs = [ pkgs.autoPatchelfHook ];
        unpackPhase = ''
          # Unpack sources
          ${pkgs.unzip}/bin/unzip $src
          mv Rack2Free $out

          # Setup wrapper
          mkdir $out/bin
          cat <<EOF> $out/bin/Rack
          #!/bin/sh
          cd $out; exec ./Rack
          EOF

          # Fix permissions
          ${pkgs.findutils}/bin/find $out -type f | xargs chmod 444
          ${pkgs.findutils}/bin/find $out -type d | xargs chmod 555
          chmod 555 $out/Rack $out/libRack.so $out/bin/Rack
        '';
        dontStrip = true;
        dontInstall = true;
      };

      reaper = pkgs.reaper.overrideAttrs (old: rec {
        version = "6.56";
        src = pkgs.fetchurl {
          url = "https://www.reaper.fm/files/6.x/reaper${
              builtins.replaceStrings [ "." ] [ "" ] version
            }_linux_x86_64.tar.xz";
          hash = "sha256-ys4cmqr70F0RMmaPDdvsFauAwQZpJSO71aKSBgB5Zbk=";
        };
      });

      pw-reaper = pkgs.writeScriptBin "pw-reaper" ''
        #!/bin/sh
        exec ${pkgs.pipewire.jack}/bin/pw-jack ${reaper}/bin/reaper $*
      '';

      pw-qjackctl = pkgs.writeScriptBin "pw-qjackctl" ''
        #!/bin/sh
        exec ${pkgs.pipewire.jack}/bin/pw-jack ${pkgs.qjackctl}/bin/qjackctl $*
      '';

    in {
      packages."x86_64-linux".vcv = vcv;
      apps."x86_64-linux".vcv = {
        type = "app";
        program = "${vcv}/bin/Rack";
      };

      packages."x86_64-linux".reaper = pw-reaper;
      apps."x86_64-linux".reaper = {
        type = "app";
        program = "${pw-reaper}/bin/pw-reaper";
      };

      packages."x86_64-linux".qjackctl = pw-qjackctl;
      apps."x86_64-linux".qjackctl = {
        type = "app";
        program = "${pw-qjackctl}/bin/pw-qjackctl";
      };

      packages."x86_64-linux".mididump = pkgs.pipewire;
      apps."x86_64-linux".mididump = {
        type = "app";
        program = "${pkgs.pipewire}/bin/pw-mididump";
      };

    };
}
