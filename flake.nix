{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    flake-utils.url = "github:numtide/flake-utils";
    nixgl.url = "github:nix-community/nixGL";
    fenix = {
      url = "github:nix-community/fenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    naersk = {
      url = "github:nix-community/naersk";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, flake-utils, naersk, nixpkgs, fenix, nixgl }:
    flake-utils.lib.eachDefaultSystem (system:
      let
      	pkgs = nixpkgs.legacyPackages.${system};
	target = "wasm32-unknown-unknown";
#        toolchain = fenix.packages.${system}.stable.withComponents [
#          "rustc"
#          "cargo"
#          "rust-src"
#          "rust-docs"
#          "rust-analyzer"
#          "clippy"
#          "rustfmt"
	toolchain = with fenix.packages.${system}; combine [
            minimal.cargo
            minimal.rustc
            targets.${target}.latest.rust-std
        ];


        naersk' = (naersk.lib.${system}.override {
          cargo = toolchain;
          rustc = toolchain;
        }).buildPackage {
          src = ./.;
          CARGO_BUILD_TARGET = target;
          CARGO_TARGET_WASM32_UNKNOWN_UNKNOWN_LINKER =
            let
              inherit (pkgs.pkgsCross.wasm32-unknown-unknown.stdenv) cc;
            in
            "${cc}/bin/${cc.targetPrefix}cc";
        };

        envLink = pkgs.runCommand "usr-bin-env" { } ''
            mkdir -p $out/usr/bin
            ln -s ${pkgs.coreutils}/bin/env $out/usr/bin/env
          '';

        imageRoot = pkgs.symlinkJoin {
          name = "image-root";
          paths = [
            self.packages.${system}.default
            pkgs.bashInteractive
            pkgs.coreutils
            pkgs.gnused
            pkgs.gnugrep
            pkgs.gawk
            pkgs.procps
            envLink
          ];
          # Ensures /bin/ is linked correctly
          # You may not need this if self.packages includes proper layout
        };
      in rec {
        # For `nix build` & `nix run`:
        packages.default = naersk'.buildPackage {
          pname = "PrimerExcavator";
          src = ./.;
        };

        # For `nix build .#dockerImage`:
        packages.dockerImage = pkgs.dockerTools.buildImage {
          name = "PrimerExcavator";
          tag = "latest";

          # Place binary under /bin/ in the image
          copyToRoot = imageRoot;

          config = {
            Cmd = [ "bash" ];
          };
        };

        # For `nix develop`
        devShell = pkgs.mkShell rec {
          nativeBuildInputs = with pkgs; [
            toolchain
            jd-diff-patch
            jq
          ];
          buildInputs = with pkgs; [
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

            # GL
            # nixgl
            nixgl.defaultPackage.${system}.nixGLIntel
          ];

          shellHook = "";
          LD_LIBRARY_PATH = "${pkgs.lib.makeLibraryPath buildInputs}";
        };

      }
    );
}
