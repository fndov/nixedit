## NixOS Rebuilding tool

`nixedit` is a simple command-line tool to automate all steps of rebuilding.

### Features:
- Search Configure Build Backup Update Delete Optimise in one step.
- Integrates with GitHub to upload backups of your configuration.
- Third Party Code: [Package search](https://github.com/niksingh710/nsearch?tab=readme-ov-file) (can't be moved to default.nix)

### Installation Instructions

You can install `nixedit` using the provided `default.nix` file. Copy & Paste to build the package.

#### Clone the Repository

This repository contains the `default.nix` and `src`. The package will be installed, designed for userland.

```
git clone https://github.com/fndov/nixedit.git
cd nixedit
nix-build            # Compile nixedit
nix-env -i ./result  # Install pacakge
```
```
# Uninstall package using:
nix-env --uninstall nixedit
