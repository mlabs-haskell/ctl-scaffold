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

  outputs =
    { self
    , nixpkgs
    , ...
    }@inputs:
    let
      defaultSystems = [ "x86_64-linux" "x86_64-darwin" ];
      perSystem = nixpkgs.lib.genAttrs defaultSystems;
      nixpkgsFor = system: import nixpkgs { inherit system; };
      psProjectFor = system:
        let
          pkgs = nixpkgsFor system;
          src = ./.;
        in
        import ./nix {
          inherit src pkgs inputs system self;
        };
    in
    {
      devShell = perSystem (system: (psProjectFor system).devShell);

      packages = perSystem (system:
        let
          pkgs = nixpkgsFor system;
          easy-ps = import inputs.easy-purescript-nix { inherit pkgs; };
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
        in
        (psProjectFor system).packages // { inherit formatting-check; }
      );

      checks = perSystem (system: (psProjectFor system).checks);

      defaultPackage = perSystem (system: (psProjectFor system).defaultPackage);
    };
}
