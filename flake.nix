{
  description = "ctl-scaffold";

  inputs = {
    flake-compat = {
      url = "github:edolstra/flake-compat";
      flake = false;
    };
    nixpkgs.url = "github:NixOS/nixpkgs?ref=nixpkgs-unstable";
    cardano-transaction-lib = {
      type = "github";
      owner = "Plutonomicon";
      repo = "cardano-transaction-lib";
      rev = "f65eb08656f9da4ad1b83b09d25422bcf4835e9c";
    };
  };

  outputs = { self, nixpkgs, cardano-transaction-lib, ... }@inputs:
    let
      defaultSystems = [ "x86_64-linux" "x86_64-darwin" ];
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
          spagoPkgsSrc = ./spago-packages.nix;
        };
    in
    {
      defaultPackage = perSystem (system: self.packages.${system}.ctl-scaffold);

      packages = perSystem (system:
        {
          ctl-scaffold = (psProjectFor system).buildPursProject {
            name = "ctl-scaffold";
          };
        });

      checks = perSystem
        (system:
          let
            pkgs = nixpkgsFor system;
            project = psProjectFor system;
          in
          {
            ctl-scaffold = project.runPursTest {
              name = "ctl-scaffold";
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

      devShell = perSystem (system:
        let
          pkgs = nixpkgsFor system;
          project = psProjectFor system;
        in
        pkgs.mkShell
          {
            buildInputs = with pkgs.easy-ps; [
              project.pursCompiler
              project.nodejs
              spago
              purs-tidy
              purescript-language-server
              pscid
              spago2nix
              pkgs.nodePackages.node2nix
              pkgs.nixpkgs-fmt
              pkgs.fd
            ];

            shellHook =
              let
                nodeModules = project.mkNodeModules { };
              in
              ''
                __ln-node-modules () {
                  local modules=./node_modules
                  if test -L "$modules"; then
                    rm "$modules";
                  elif test -e "$modules"; then
                    echo 'refusing to overwrite existing (non-symlinked) `node_modules`'
                    exit 1
                  fi

                  ln -s ${nodeModules}/lib/node_modules "$modules"
                }

                __ln-node-modules

                export PATH="${nodeModules}/bin:$PATH"
              '';
          });
    };
}
