{
  description = "modularix";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs";
    nixpkgs-wine.url =
      "github:NixOS/nixpkgs/94073c2546d20efc0ae206b41fc0b775f1e06dab";
    nixgl.url = "github:nix-community/nixGL";
  };

  outputs = { self, nixgl, nixpkgs, nixpkgs-unstable, nixpkgs-wine }:
    let
      pkgs = import nixpkgs {
        localSystem = "x86_64-linux";
        config.allowUnfree = true;
        overlays = [ nixgl.overlay ];
      };
      pkgs-unstable = import nixpkgs-unstable {
        localSystem = "x86_64-linux";
        config.allowUnfree = true;
        overlays = [ nixgl.overlay ];
      };
      pkgs-wine = import nixpkgs-wine {
        localSystem = "x86_64-linux";
        overlays = [ nixgl.overlay ];
      };

      fabla = pkgs.stdenv.mkDerivation rec {
        name = "fabla";
        src = pkgs.fetchFromGitHub {
          owner = "openAVproductions";
          repo = "openAV-Fabla";
          rev = "163796e416b5f52198cb8066ecfc3600a76cb9d1";
          sha256 = "sha256-B2I4hI7rAgGuh8RwgeicDwzDEoea5WZVhNdCpZF6P0c=";
        };
        nativeBuildInputs = [ pkgs.cmake pkgs.pkg-config ];
        buildInputs = with pkgs; [ ntk cairo cairomm libsndfile lv2 libGL ];
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

      surge = pkgs.stdenv.mkDerivation rec {
        pname = "surge";
        version = "1.3.1";
        src = pkgs.fetchurl {
          url =
            "https://github.com/surge-synthesizer/releases-xt/releases/download/${version}/surge-xt-linux-${version}-pluginsonly.tar.gz";
          sha256 = "1rsbrcpf3q9p23ag2hpzzs67bl9sswa3v2lyc2znmym8gmknnjbv";
        };
        unpackPhase = ''
          # Unpack sources
          mkdir $out
          pushd $out
          tar xf $src
          popd

          # Setup wrapper
          mkdir -p $out/bin
          ln -s $out/surge-xt-cli $out/bin/surge-xt-cli
        '';
        dontStrip = true;
        dontInstall = true;
      };

      blender = pkgs.stdenv.mkDerivation rec {
        pname = "blender";
        version = "4.2.1";
        src = pkgs.fetchurl {
          url =
            "https://mirrors.ocf.berkeley.edu/blender/release/Blender4.2/blender-${version}-linux-x64.tar.xz";
          sha256 = "sha256-vg+6oMHlLUVSAjIgtMZzUe+7cHysSbs4H8vuIYJEcAU=";
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
        version = "2.5.2";
        src = pkgs.fetchurl {
          url = "https://vcvrack.com/downloads/RackFree-${version}-lin-x64.zip";
          sha256 = "sha256-bHu6XzzPj+Zndx3dJhnGoX+Etd/THTaD9WwlPidinKE=";
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
        version = "733";
        src = pkgs.fetchurl {
          url =
            "http://reaper.fm/files/7.x/reaper${version}_linux_x86_64.tar.xz";
          sha256 = "sha256-C+iJO6hQib2Z5FKB2dBRD963x9ezSt8G3E3ocaY56TI=";
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
               pkgs.cairo
               pkgs.xorg.xcbutil
               pkgs.xorg.xcbutilkeysyms
             ]
           }"

          # Setup wrapper
          mkdir -p $out/bin
          ln -s $out/reaper $out/bin/reaper
        '';
        dontStrip = true;
        dontInstall = true;
      };

      reapack = pkgs.stdenv.mkDerivation rec {
        pname = "reapack";
        version = "1.2.5";
        src = pkgs.fetchFromGitHub {
          owner = "cfillion";
          repo = "reapack";
          rev = "b4ede68f2a41ef4da62f65c2a13c72d9f5d8d993";
          sha256 = "sha256-RhXAjTNAJegeCJaYkvwJedZrXRA92dQ0EeHJr9ngeCg=";
          fetchSubmodules = true;
        };
        nativeBuildInputs = [ pkgs.cmake pkgs.pkg-config ];
        buildInputs = with pkgs; [
          boost
          curl
          zlib
          libxml2
          sqlite
          php
          catch2_3
        ];
      };

      sws = pkgs.stdenv.mkDerivation rec {
        pname = "sws";
        version = "2.14.0.3";
        src = pkgs.fetchgit {
          url = "https://github.com/reaper-oss/sws.git";
          rev = "539b524f04f7b9d7b3adb874125d42e46d3aba10";
          sha256 = "sha256-CActmbwniTvF0Qv4Cq75Yc9UsHrRhLsMzJm4+FypPzA=";
          leaveDotGit = true;
          fetchSubmodules = true;
        };
        nativeBuildInputs = [ pkgs.cmake pkgs.pkg-config pkgs.git ];
        buildInputs = with pkgs; [
          boost
          curl
          zlib
          libxml2
          sqlite
          php
          gtk3
          gdk-pixbuf
          gobject-introspection
        ];
      };

      hspkgs = pkgs.haskellPackages.extend (hpFinal: hpPrev:
        let
          src = pkgs.fetchFromGitHub {
            owner = "tidalcycles";
            repo = "Tidal";
            rev = "2127647dfc25c0a7fe4037f6da81e1f4695e7258";
            sha256 = "sha256-lIe7gVjDiNZGI/+AxSWPD54Gd7tZoO+MtfmZF7PAEnQ=";
          };
        in {
          tidal = hpPrev.callCabal2nix "tidal" src { };
          tidal-parse =
            hpPrev.callCabal2nix "tidal-parse" "${src}/tidal-parse" { };
          tidal-link = hpPrev.callCabal2nix "tidal" "${src}/tidal-link" { };
        });

      tidal = hspkgs.ghcWithPackages (p: [ p.tidal ]);

      supercollider = pkgs.supercollider-with-sc3-plugins;

      # https://github.com/free-audio/clap-host
      clap-host = pkgs.stdenv.mkDerivation rec {
        pname = "clap-host";
        version = "1.0.3";
        src = pkgs.fetchFromGitHub {
          owner = "free-audio";
          repo = "clap-host";
          rev = "6a081ba4a2bc4ec6003a8bb4d60dbdeb28a4a11f";
          sha256 = "sha256-fdmsftmz31Ub7iQ1IkTM69hCbSXomDlO6JHKfGWXwK4=";
          fetchSubmodules = true;
        };
        nativeBuildInputs = [ pkgs.cmake pkgs.pkg-config ];
        buildInputs = with pkgs; [ qt6.full rtaudio_6 rtmidi ];
      };

      install-yabridge = {
        type = "app";
        program = let
          wrapper = pkgs.writeScriptBin "install-yabridge" ''
            #!/bin/sh
            export PATH=${pkgs-wine.yabridgectl}/bin:${pkgs-wine.yabridge}/bin/:$PATH
            mkdir -p ~/.local/share/yabridge
            cp $(dirname $(which yabridge-host.exe))/* $(dirname $(which yabridge-host.exe))/../lib/* ~/.local/share/yabridge/
            yabridgectl add ~/.wine/drive_c/Program\ Files/Steinberg/VSTPlugins/
            yabridgectl add ~/.wine/drive_c/Program\ Files/Common\ Files/VST3/
            echo "Running: $(type -p yabridgectl) sync"
            yabridgectl sync
          '';
        in "${wrapper}/bin/install-yabridge";
      };

      install-reapack = {
        type = "app";
        program = let
          wrapper = pkgs.writeScriptBin "reaper-reapack" ''
            #!/bin/sh
            echo ln -s ${reapack}/UserPlugins/reaper_reapack-x86_64.so \$HOME/.config/REAPER/UserPlugins
            ln -s ${reapack}/UserPlugins/reaper_reapack-x86_64.so ~/.config/REAPER/UserPlugins
          '';
        in "${wrapper}/bin/reaper-reapack";
      };

      install-sws = {
        type = "app";
        program = let
          wrapper = pkgs.writeScriptBin "reaper-sws" ''
            #!/bin/sh
            echo ln -s ${sws}/UserPlugins/reaper_sws-x86_64.so \$HOME/.config/REAPER/UserPlugins
            ln -s ${sws}/UserPlugins/reaper_sws-x86_64.so \$HOME/.config/REAPER/UserPlugins
          '';
        in "${wrapper}/bin/reaper-reapack";
      };

      mkFlake = name: pkg: command:
        let
          wrapper = pkgs.writeScriptBin command ''
            #!/bin/sh
            export PATH=$PATH:${pkgs.zenity}/bin:${pkg}/bin
            exec ${pkgs.pipewire.jack}/bin/pw-jack ${pkg}/bin/${command} $*
          '';
        in {
          packages."x86_64-linux"."${name}" = wrapper;
          apps."x86_64-linux"."${name}" = {
            type = "app";
            program = "${wrapper}/bin/${command}";
          };
        };

      reaper-gl = {
        type = "app";
        program = let
          wrapper = pkgs.writeScriptBin "reaper-gl" ''
            #!/bin/sh

            exec ${pkgs-wine.nixgl.auto.nixGLDefault}/bin/nixGL ${pkgs.pipewire.jack}/bin/pw-jack ${reaper}/bin/reaper $*
          '';
        in "${wrapper}/bin/reaper-gl";
      };

    in pkgs.lib.foldr pkgs.lib.recursiveUpdate {
      packages.x86_64-linux.bespoke = pkgs-unstable.bespokesynth;
      packages.x86_64-linux.qpwgraph = pkgs.qpwgraph;
      packages.x86_64-linux.plugdata = pkgs.plugdata;
      packages.x86_64-linux.puredata = pkgs.puredata;
      packages.x86_64-linux.audiowaveform = pkgs.audiowaveform;
      packages.x86_64-linux.fabla = fabla;
      packages.x86_64-linux.lsp-plugins = pkgs-unstable.lsp-plugins;
      packages.x86_64-linux.reapack = reapack;
      packages.x86_64-linux.sws = sws;
      packages.x86_64-linux.clap-host = clap-host;
      packages.x86_64-linux.tidal = tidal;
      devShells.x86_64-linux.yabridge = pkgs.mkShell {
        buildInputs = [ pkgs-wine.yabridge pkgs-wine.yabridgectl ];
      };
      devShells.x86_64-linux.tidal =
        pkgs.mkShell { buildInputs = [ tidal pkgs.cabal-install ]; };
      apps.x86_64-linux.blender-humans = open-human-bundle;
      apps.x86_64-linux.reapack = install-reapack;
      apps.x86_64-linux.install-yabridge = install-yabridge;
      apps.x86_64-linux.sws = install-sws;
      apps.x86_64-linux.reaper-gl = reaper-gl;
    } [
      (mkFlake "supercollider" supercollider "scide")
      (mkFlake "sclang" supercollider "sclang")
      (mkFlake "vcv" vcv "Rack")
      (mkFlake "cardinal" cardinal "Cardinal")
      (mkFlake "surge" surge "surge-xt-cli")
      (mkFlake "reaper" reaper "reaper")
      (mkFlake "blender" blender "blender")
      (mkFlake "qjackctl" pkgs.qjackctl "qjackctl")
      (mkFlake "mididump" pkgs.pipewire "pw-mididump")
    ];
}
