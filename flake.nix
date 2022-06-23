{
  description = "ctl-scaffold";

  inputs = {
    flake-compat = {
      url = "github:edolstra/flake-compat";
      flake = false;
    };
    cardano-transaction-lib = {
      type = "github";
      owner = "Plutonomicon";
      repo = "cardano-transaction-lib";
      rev = "cb0af8f023a7f5f1cadeba8a8f2e02523f661371";
    };
    nixpkgs.follows = "cardano-transaction-lib/nixpkgs";
  };

  outputs = { self, nixpkgs, cardano-transaction-lib, ... }@inputs:
    let
      defaultSystems = [
        "x86_64-linux"
        "x86_64-darwin"
        "aarch64-linux"
        "aarch64-darwin"
      ];
      perSystem = nixpkgs.lib.genAttrs defaultSystems;
      nixpkgsFor = system: import nixpkgs {
        inherit system;
        overlays = [ cardano-transaction-lib.overlay.${system} ];
      };
      psProjectFor = system:
        let
          pkgs = nixpkgsFor system;
          src = ./.;
        in
        pkgs.purescriptProject {
          inherit pkgs src;
          projectName = "ctl-scaffold";
        };
    in
    {
      defaultPackage = perSystem (system:
        self.packages.${system}.ctl-scaffold-bundle-web
      );

      packages = perSystem (system: {
        ctl-scaffold-bundle-web = (psProjectFor system).bundlePursProject {
          sources = [ "src" ];
          main = "Main";
        };
        ctl-scaffold-runtime = (nixpkgsFor system).buildCtlRuntime { };
      });

      apps = perSystem (system: {
        ctl-scaffold-runtime = (nixpkgsFor system).launchCtlRuntime { };
      });

      checks = perSystem (system:
        let
          pkgs = nixpkgsFor system;
        in
        {
          ctl-scaffold = (psProjectFor system).runPursTest {
            sources = [ "src" "test" ];
          };
          formatting-check = pkgs.runCommand "formatting-check"
            {
              nativeBuildInputs = [
                pkgs.easy-ps.purs-tidy
                pkgs.fd
              ];
            }
            ''
              cd ${self}
              purs-tidy check $(fd -epurs)
              touch $out
            '';
        });

      devShell = perSystem (system: (psProjectFor system).devShell);
    };
}
