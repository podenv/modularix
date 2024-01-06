{
  description = "modularix";

  inputs = { nixpkgs.url = "github:NixOS/nixpkgs"; };

  outputs = { self, nixpkgs }:
    let
      pkgs = import nixpkgs {
        localSystem = "x86_64-linux";
        config.allowUnfree = true;
      };

      blender = pkgs.stdenv.mkDerivation rec {
        pname = "blender";
        version = "4.0.2";
        src = pkgs.fetchurl {
          url = "https://mirrors.ocf.berkeley.edu/blender/release/Blender4.0/blender-${version}-linux-x64.tar.xz";
          sha256 = "sha256-VYOlWIc22ohYxSLvF//11zvlnEem/pGtKcbzJj4iCGo=";
        };
        unpackPhase = ''
          # Unpack sources
          tar xf $src
          mv blender-* $out

          # Setup wrapper
          mkdir $out/bin
          cat <<EOF> $out/bin/blender
          #!/bin/sh
          export LD_LIBRARY_PATH=${pkgs.libdecor}/lib
          exec $out/blender \$*
          EOF
          chmod +x $out/bin/blender
        '';
        dontStrip = true;
        dontInstall = true;
      };

      human-base-meshes-bundle = pkgs.stdenv.mkDerivation rec {
        pname = "human-base-meshes-bundle";
        version = "1.0.0";
        src = pkgs.fetchurl {
          url = "https://mirrors.ocf.berkeley.edu/blender/demo/bundles/bundles-3.6/human-base-meshes-bundle-v${version}.zip";
          sha256 = "sha256-RqkSwFJAcqw7eMNdXSRx33uN8QI5SgUMqM1xhOM5Nkg=";
        };
        unpackPhase = ''
          # Unpack sources
          mkdir -p $out
          cd $out
          ${pkgs.unzip}/bin/unzip $src
        '';
        dontStrip = true;
        dontInstall = true;
      };
      open-human-bundle = {
        type = "app";
        program =
          let wrapper = pkgs.writeScriptBin "blender-open-human-bundle" ''
            #!/bin/sh
            echo exec ${blender}/bin/blender ${human-base-meshes-bundle}/human_base_meshes_bundle.blend
            exec ${blender}/bin/blender ${human-base-meshes-bundle}/human_base_meshes_bundle.blend
            '';
           in "${wrapper}/bin/blender-open-human-bundle";
      };

      vcv = pkgs.stdenv.mkDerivation rec {
        pname = "Rack";
        version = "2.4.1";
        src = pkgs.fetchurl {
          url = "https://vcvrack.com/downloads/RackFree-${version}-lin-x64.zip";
          sha256 = "sha256-Q3W02PpNsVIV+8VBEhfwshiRKWGg4WdEU4XWX2+GxwM=";
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

      mkFlake = name: pkg: command:
        let
          wrapper = pkgs.writeScriptBin command ''
            #!/bin/sh
            exec ${pkgs.pipewire.jack}/bin/pw-jack ${pkg}/bin/${command} $*
          '';
        in {
          packages."x86_64-linux"."${name}" = wrapper;
          apps."x86_64-linux"."${name}" = {
            type = "app";
            program = "${wrapper}/bin/${command}";
          };
        };

    in pkgs.lib.foldr pkgs.lib.recursiveUpdate {
      packages.x86_64-linux.qpwgraph = pkgs.qpwgraph;
      apps.x86_64-linux.blender-humans = open-human-bundle;
    } [
      (mkFlake "vcv" vcv "Rack")
      (mkFlake "reaper" reaper "reaper")
      (mkFlake "blender" blender "blender")
      (mkFlake "qjackctl" pkgs.qjackctl "qjackctl")
      (mkFlake "mididump" pkgs.pipewire "pw-mididump")
    ];
}
