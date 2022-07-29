# ctl-scaffold

## Deprecated

This repository is **deprecated** and will be archived soon.

`ctl-scaffold` is moving to the [CTL repo](https://github.com/Plutonomicon/cardano-transaction-lib/) itself.

You can initialize a new CTL-based project using `nix flake init`, e.g.

```
$ mkdir ctl-project && cd ctl-project
$ git init
$ nix flake init -t 'github:Plutonomicon/cardano-transaction-lib?rev=c9c32a5f6a71799b194d4cc6237379ddef178018#ctl-scaffold'
```
