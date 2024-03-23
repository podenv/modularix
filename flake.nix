{
  description = "modularix";

  inputs = { nixpkgs.url = "github:NixOS/nixpkgs"; };

  outputs = { self, nixpkgs }:
    let
      pkgs = import nixpkgs {
        localSystem = "x86_64-linux";
        config.allowUnfree = true;
      };

      cardinal = pkgs.stdenv.mkDerivation rec {
        pname = "cardinal";
        version = "23.10";
        src = pkgs.fetchurl {
          url =
            "https://github.com/DISTRHO/Cardinal/releases/download/23.10/Cardinal-linux-x86_64-${version}.tar.gz";
          sha256 = "sha256-uC0rKY3uNC7zuRkaeIZQkrc0CuxfyvXFhs32cFBm/vw=";
        };
        unpackPhase = ''
          # Unpack sources
          mkdir $out
          pushd $out
          tar xf $src
          popd

          # Setup wrapper
          mkdir -p $out/bin
          ln -s $out/CardinalJACK $out/bin/Cardinal
        '';
        dontStrip = true;
        dontInstall = true;
      };

      blender = pkgs.stdenv.mkDerivation rec {
        pname = "blender";
        version = "4.0.2";
        src = pkgs.fetchurl {
          url =
            "https://mirrors.ocf.berkeley.edu/blender/release/Blender4.0/blender-${version}-linux-x64.tar.xz";
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
          url =
            "https://mirrors.ocf.berkeley.edu/blender/demo/bundles/bundles-3.6/human-base-meshes-bundle-v${version}.zip";
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
        program = let
          wrapper = pkgs.writeScriptBin "blender-open-human-bundle" ''
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

      reaper = pkgs.stdenv.mkDerivation rec {
        pname = "reaper";
        version = "711";
        src = pkgs.fetchurl {
          url =
            "http://reaper.fm/files/7.x/reaper${version}_linux_x86_64.tar.xz";
          sha256 = "sha256-lpgGXHWWhhs1jLllq5C3UhOLgLyMTE6qWFiGkBcuWlo=";
        };
        nativeBuildInputs =
          [ pkgs.makeWrapper pkgs.which pkgs.autoPatchelfHook pkgs.xdg-utils ];
        buildInputs = [ pkgs.stdenv.cc.cc.lib pkgs.gtk3 pkgs.alsa-lib ];
        runtimeDependencies = [
          pkgs.gtk3 # libSwell needs libgdk-3.so.0
        ];
        unpackPhase = ''
          tar xf $src
          mv */REAPER $out

          wrapProgram $out/reaper \
           --prefix LD_LIBRARY_PATH : "${
             pkgs.lib.makeLibraryPath [
               pkgs.lame
               pkgs.ffmpeg
               pkgs.vlc
               pkgs.xdotool
             ]
           }"

          # Setup wrapper
          mkdir -p $out/bin
          ln -s $out/reaper $out/bin/reaper
        '';
        dontStrip = true;
        dontInstall = true;
      };

      mkFlake = name: pkg: command:
        let
          wrapper = pkgs.writeScriptBin command ''
            #!/bin/sh
            export PATH=$PATH:${pkgs.gnome.zenity}/bin
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
      (mkFlake "cardinal" cardinal "Cardinal")
      (mkFlake "reaper" reaper "reaper")
      (mkFlake "blender" blender "blender")
      (mkFlake "qjackctl" pkgs.qjackctl "qjackctl")
      (mkFlake "mididump" pkgs.pipewire "pw-mididump")
    ];
}
