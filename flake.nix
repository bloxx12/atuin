{
  inputs = {
    nixpkgs.url = "https://channels.nixos.org/nixpkgs-unstable/nixexprs.tar.xz";
    flake-compat = {
      url = "github:edolstra/flake-compat";
      flake = false;
    };
    fenix = {
      url = "github:nix-community/fenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
  outputs =
    {
      self,
      nixpkgs,
      fenix,
      ...
    }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];
      forEachSystem = nixpkgs.lib.genAttrs systems;
      pkgsForEach = nixpkgs.legacyPackages;

      toolchainFor =
        system:
        fenix.packages.${system}.fromToolchainFile {
          file = ./rust-toolchain.toml;
          sha256 = "sha256-h+t2xTBz5yt2YIO+1VMIIGlCU7gyp2LYOFvaV1nwOXU=";
        };
    in
    {
      packages = forEachSystem (
        system:
        let
          pkgs = pkgsForEach.${system};
          toolchain = toolchainFor system;
        in
        {
          atuin = pkgs.callPackage ./atuin.nix {
            rustPlatform = pkgs.makeRustPlatform {
              cargo = toolchain;
              rustc = toolchain;
            };
          };
          default = self.packages.${system}.atuin;
        }
      );

      devShells = forEachSystem (
        system:
        let
          pkgs = pkgsForEach.${system};
          toolchain = toolchainFor system;
        in
        {
          default = pkgs.mkShell {
            inputsFrom = [ self.packages.${system}.atuin ];

            packages = [
              toolchain
              pkgs.cargo-edit
            ];

            RUST_SRC_PATH = "${pkgs.rustPlatform.rustLibSrc}";

            shellHook = ''
              echo >&2 "Setting development database path"
              export ATUIN_DB_PATH="/tmp/atuin_dev.db"
              export ATUIN_RECORD_STORE_PATH="/tmp/atuin_records.db"

              if [ -e "''${ATUIN_DB_PATH}" ]; then
                echo >&2 "''${ATUIN_DB_PATH} already exists, you might want to double-check that"
              fi

              if [ -e "''${ATUIN_RECORD_STORE_PATH}" ]; then
                echo >&2 "''${ATUIN_RECORD_STORE_PATH} already exists, you might want to double-check that"
              fi
            '';
          };
        }
      );

      overlays.default = final: _prev: {
        inherit (self.packages.${final.stdenv.hostPlatform.system}) atuin;
      };

      formatter = forEachSystem (system: pkgsForEach.${system}.nixfmt);
    };
}
