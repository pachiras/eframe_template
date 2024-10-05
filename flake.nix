{
  description = "wasm-pack setup";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    rust-overlay.url = "github:oxalica/rust-overlay";
  };

  outputs = { nixpkgs, rust-overlay, ... }:
    let system = "x86_64-linux";
    in {
      devShell.${system} = let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [
            rust-overlay.overlays.default
          ];
        };

      in with pkgs;
        pkgs.mkShell rec {
          buildInputs = [
            # Web
            trunk
            nodejs
            wasm-pack
            
            # misc. libraries
            nil
            pkg-config
            zlib
            openssl
            which
            git 

            # GUI libs
            libxkbcommon
            libGL
            fontconfig

            # wayland libraries
            wayland

            # x11 libraries
            xorg.libXcursor
            xorg.libXrandr
            xorg.libXi
            xorg.libX11
            
            # Rust
            (rust-bin.stable.latest.default.override {
              extensions = [ "clippy" "rls" "rust-analysis" "rust-src" "rust-docs" "rustfmt" "rust-analyzer" ];
              targets = [ "wasm32-unknown-unknown" ];
            })
            cargo
            cargo-watch
          ];

          shellHook = "";
          LD_LIBRARY_PATH = "${lib.makeLibraryPath buildInputs}:$LD_LIBRARY_PATH";
        };
    };
}
