{
  description = "OmniBoard development toolchain (Core, protocol, providers, tools)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, flake-utils, rust-overlay }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        overlays = [ (import rust-overlay) ];
        pkgs = import nixpkgs { inherit system overlays; };

        rustToolchain = pkgs.rust-bin.stable.latest.default.override {
          extensions = [ "rust-src" "rustfmt" "clippy" "rust-analyzer" ];
        };
      in
      {
        devShells.default = pkgs.mkShell {
          name = "omniboard";

          packages = with pkgs; [
            rustToolchain
            pkg-config
            openssl
            sqlite
            libiconv
            nodejs_22
            python3
            jq
            just
            git
          ];

          RUST_SRC_PATH = "${rustToolchain}/lib/rustlib/src/rust/library";
          # Ensure flake rustc/cargo win over any host ~/.cargo/bin.
          shellHook = ''
            export PATH="${rustToolchain}/bin:$PATH"
            echo "OmniBoard nix flake: $(rustc --version) | node $(node --version)"
          '';
        };

        packages.default = pkgs.writeText "omniboard-devshell-hint" ''
          Enter the toolchain with: nix develop
        '';

        formatter = pkgs.nixpkgs-fmt;
      });
}
