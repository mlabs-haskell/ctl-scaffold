{ src
, pkgs
, system
, inputs
, self
}:

let
  # We should try to use a consistent version of node across all
  # project components
  nodejs = pkgs.nodejs-12_x;
  easy-ps = import inputs.easy-purescript-nix { inherit pkgs; };
  compiler = easy-ps.purs-0_14_5;
  spagoPkgs = import ../spago-packages.nix { inherit pkgs; };
  nodeEnv = import
    (pkgs.runCommand "nodePackages"
      {
        buildInputs = [ pkgs.nodePackages.node2nix ];
      } ''
      mkdir $out
      cp ${src}/package.json $out/package.json
      cp ${src}/package-lock.json $out/package-lock.json
      cd $out
      node2nix --lock package-lock.json
    '')
    { inherit pkgs nodejs system; };
  nodeModules =
    let
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

  buildPursProject =
    { name
    , src
    , filter ? name: type:
        builtins.any (ext: pkgs.lib.hasSuffix ext name) [
          ".purs"
          ".dhall"
        ]
    }:
    let
      cleanedSrc = builtins.path {
        inherit filter;
        name = "src";
        path = src;
      };
    in
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
      unpackPhase = ''
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
          node -e 'require("./output/Test.Main").main()'
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

        shellHook = ''
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
}
