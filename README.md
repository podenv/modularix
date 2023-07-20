# modularix - Digital Audio Workstation powered by Nix Flakes

On a pipewire enabled host, run the applications with:

```ShellSession
$ nix run github:podenv/modularix#app
```

Available app:

- qpwgraph
- vcv
- reaper
- mididump

- blender-3.6.1

Deprecated by qpwgraph:
- qjackctl

## Usage

Get the list of installables:

```ShellSession
$ nix flake show github:podenv/modularix
```

Use a pinned url by adding a GIT_REF:

```ShellSession
$ nix flake show github:podenv/modularix/4a179844b0e00829180d548bf5a3bcc692b2c5eb
```

Build a package:

```ShellSession
$ nix build github:podenv/modularix#mididump
```

Get the dependencies tree:

```ShellSession
$ nix-store -q --tree $(nix path-info github:podenv/modularix#mididump)
```
