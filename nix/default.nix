{ src
, pkgs
, system
, inputs
, self
}:

let
  ps-lib = import ./lib.nix {
    inherit pkgs easy-ps spagoPkgs nodejs nodeModules;
  };
  # We should try to use a consistent version of node across all
  # project components
  nodejs = pkgs.nodejs-12_x;
  easy-ps = import inputs.easy-purescript-nix { inherit pkgs; };
  spagoPkgs = import ../spago-packages.nix { inherit pkgs; };
  nodeModules =
    let
      modules = pkgs.callPackage
        (_:
          let
            nodePkgs = import ../node2nix.nix {
              inherit pkgs system nodejs;
            };
          in
          nodePkgs // {
            shell = nodePkgs.shell.override {
              # see https://github.com/svanderburg/node2nix/issues/198
              buildInputs = [ pkgs.nodePackages.node-gyp-build ];
            };
          });
    in
    (modules { }).shell.nodeDependencies;
in
{
  defaultPackage = self.packages.${system}.ctl-scaffold;

  packages = {
    ctl-scaffold = ps-lib.buildPursProject {
      name = "ctl-scaffold";
      subdir = "exe";
      inherit src;
    };
  };

  checks = {
    ctl-scaffold = ps-lib.runPursTest {
      name = "ctl-scaffold";
      subdir = "test";
      inherit src;
    };
  };

  devShell = import ./dev-shell.nix {
    inherit pkgs system inputs nodeModules easy-ps nodejs;
  };
}
