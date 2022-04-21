{
  description = "ctl-scaffold";

  inputs = {
    flake-compat = {
      url = "github:edolstra/flake-compat";
      flake = false;
    };
    nixpkgs.url = "github:NixOS/nixpkgs?ref=nixpkgs-unstable";
    easy-purescript-nix = {
      url = "github:justinwoo/easy-purescript-nix";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, ... }@inputs:
    let
      defaultSystems = [ "x86_64-linux" "x86_64-darwin" ];
      perSystem = nixpkgs.lib.genAttrs defaultSystems;
      nixpkgsFor = system: import nixpkgs { inherit system; };
      psProjectFor = system:
        let
          pkgs = nixpkgsFor system;
          src = ./.;
          nodejs = pkgs.nodejs-12_x;
          easy-ps = import inputs.easy-purescript-nix { inherit pkgs; };
          compiler = easy-ps.purs-0_14_5;
          spagoPkgs = import ./spago-packages.nix { inherit pkgs; };
          mkNodeEnv = { withDevDeps ? true }: import
            (pkgs.runCommand "nodePackages"
              {
                buildInputs = [ pkgs.nodePackages.node2nix ];
              } ''
              mkdir $out
              cp ${src}/package.json $out/package.json
              cp ${src}/package-lock.json $out/package-lock.json
              cd $out
              node2nix ${pkgs.lib.optionalString withDevDeps "--development" } \
                --lock package-lock.json
            '')
            { inherit pkgs nodejs system; };
          mkNodeModules = { withDevDeps ? true }:
            let
              nodeEnv = mkNodeEnv { inherit withDevDeps; };
              modules = pkgs.callPackage
                (_:
                  nodeEnv // {
                    shell = nodeEnv.shell.override {
                      # see https://github.com/svanderburg/node2nix/issues/198
                      buildInputs = [ pkgs.nodePackages.node-gyp-build ];
                    };
                  });
            in
            (modules { }).shell.nodeDependencies;

          buildPursProject = { name, src, withDevDeps ? false, ... }:
            pkgs.stdenv.mkDerivation {
              inherit name src;
              buildInputs = [
                spagoPkgs.installSpagoStyle
                spagoPkgs.buildSpagoStyle
              ];
              nativeBuildInputs = [
                compiler
                easy-ps.spago
              ];
              unpackPhase =
                let
                  nodeModules = mkNodeModules { inherit withDevDeps; };
                in
                ''
                  export HOME="$TMP"

                  cp -r ${nodeModules}/lib/node_modules .
                  chmod -R u+rw node_modules
                  cp -r $src .

                  install-spago-style
                '';
              buildPhase = ''
                build-spago-style "./**/*.purs"
              '';
              installPhase = ''
                mkdir $out
                mv output $out/
              '';
            };

          runPursTest = { name, testMain ? "Test.Main", ... }@args:
            (buildPursProject args).overrideAttrs
              (oldAttrs: {
                name = "${name}-check";
                doCheck = true;
                buildInputs = oldAttrs.buildInputs ++ [ nodejs ];
                # spago will attempt to download things, which will fail in the
                # sandbox (idea taken from `plutus-playground-client`)
                checkPhase = ''
                  node -e 'require("./output/${testMain}").main()'
                '';
                installPhase = ''
                  touch $out
                '';
              });
        in
        {
          defaultPackage = self.packages.${system}.ctl-scaffold;

          packages = {
            ctl-scaffold = buildPursProject {
              name = "ctl-scaffold";
              inherit src;
            };
          };

          checks = {
            ctl-scaffold = runPursTest {
              name = "ctl-scaffold";
              inherit src;
            };
            formatting-check = pkgs.runCommand "formatting-check"
              {
                nativeBuildInputs = [
                  easy-ps.purs-tidy
                  pkgs.fd
                ];
              }
              ''
                cd ${self}
                purs-tidy check $(fd -epurs)
                touch $out
              '';
          };

          devShell =
            pkgs.mkShell
              {
                buildInputs = with easy-ps; [
                  spago
                  compiler
                  purs-tidy
                  purescript-language-server
                  pscid
                  spago2nix
                  pkgs.nodePackages.node2nix
                  nodejs
                  pkgs.nixpkgs-fmt
                  pkgs.fd
                ];

                shellHook =
                  let
                    nodeModules = mkNodeModules { };
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
              };
        };
    in
    {
      devShell = perSystem (system: (psProjectFor system).devShell);

      packages = perSystem (system: (psProjectFor system).packages);

      checks = perSystem (system: (psProjectFor system).checks);

      defaultPackage = perSystem (system: (psProjectFor system).defaultPackage);
    };
}
