{
    description = "A very basic flake";

    inputs = {
        nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

        systems.url = "github:nix-systems/default";

        flake-parts.url = "github:hercules-ci/flake-parts";
        flake-parts.inputs.nixpkgs-lib.follows = "nixpkgs";

        devshell.url = "github:numtide/devshell";
        devshell.inputs.nixpkgs.follows = "nixpkgs";

        nvim.url = "github:zms-dev/nix-nvim";
        nvim.inputs.nixpkgs.follows = "nixpkgs";
        nvim.inputs.flake-parts.follows = "flake-parts";
        nvim.inputs.devshell.follows = "devshell";

        fenix.url = "github:nix-community/fenix";
        fenix.inputs.nixpkgs.follows = "nixpkgs";
        fenix.inputs.rust-analyzer-src.follows = "";

        crane.url = "github:ipetkov/crane";

        advisory-db.url = "github:rustsec/advisory-db";
        advisory-db.flake = false;
    };

    outputs =
        inputs@{ self, nixpkgs, flake-parts, fenix, crane, advisory-db, ... }:
        flake-parts.lib.mkFlake { inherit inputs; }{
            imports = [
                inputs.devshell.flakeModule
                inputs.nvim.flakeModule
            ];

            systems = import inputs.systems;

            perSystem = { self, system, pkgs, config, ... }:
                let 
                    inherit (pkgs) lib;
                    
                    fenix' = fenix.packages.${system};
                    craneLib = crane.mkLib pkgs;
                    src = craneLib.cleanCargoSource ./.;

                    rustToolchain = fenix'.fromToolchainFile {
                        file = ./rust-toolchain.toml;
                        sha256 = "sha256-6lRcCTSUmWOh0GheLMTZkY7JC273pWLp2s98Bb2REJQ=";
                    };

                    commonArgs = {
                        inherit src;
                        strictDeps = true;
                        buildInputs = [];
                    };

                    cargoArtifacts = craneLib.buildDepsOnly commonArgs;

                    individualCrateArgs = commonArgs // {
                        inherit cargoArtifacts;
                        inherit (craneLib.crateNameFromCargoToml { inherit src; }) version;
                        # NB: we disable tests since we'll run them all via cargo-nextest
                        doCheck = false;
                    };

                    fileSetForCrate = crate: lib.fileset.toSource {
                      root = ./.;
                      fileset = lib.fileset.unions [
                        ./Cargo.toml
                        ./Cargo.lock
                        crate
                      ];
                    };
                in
                {   
                    nvim.enableRust = true;

                    packages.protocrust-lexer = craneLib.buildPackage (individualCrateArgs // {
                        pname = "protocrust-lexer";
                        src = fileSetForCrate ./protocrust-lexer;
                        cargoExtraArgs = "-p protocrust-lexer";
                    });

                    devshells.default.packages = [
                        rustToolchain
                        pkgs.gcc
                    ];

                    devshells.default.commands = [
                        {
                            name = "cargo";
                            package = rustToolchain;
                            category = "rust";
                        }
                    ];

                    checks.cargo-clippy = craneLib.cargoClippy (commonArgs // {
                        inherit cargoArtifacts;
                        cargoClippyExtraArgs = "--all-targets -- --deny warnings";
                    });

                    checks.cargo-doc = craneLib.cargoDoc (commonArgs // {
                        inherit cargoArtifacts;
                    });

                    checks.cargo-format = craneLib.cargoFmt {
                        inherit src;
                    };

                    checks.cargo-audit = craneLib.cargoAudit {
                        inherit src advisory-db;
                    };

                    checks.cargo-deny = craneLib.cargoDeny {
                        inherit src;
                    };

                    checks.cargo-nextest = craneLib.cargoNextest (commonArgs // {
                        inherit cargoArtifacts;
                        partitions = 1;
                        partitionType = "count";
                    });
                };
        };
}