{ pkgs
, system
, inputs
, nodeModules
, easy-ps
, nodejs
, compiler ? easy-ps.purs-0_14_5
, ...
}:

with inputs;

pkgs.mkShell {
  buildInputs = with easy-ps; [
    compiler
    spago
    purs-tidy
    purescript-language-server
    pscid
    spago2nix
    pkgs.nodePackages.node2nix
    nodejs
    pkgs.nixpkgs-fmt
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
}
