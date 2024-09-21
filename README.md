## Nixedit
A tool for managing your NixOS Configuration & System. Automate NixOS at every step.

### Features:
- Search Configure Build Backup Update Delete Optimise in one step.
- Integrates with GitHub to upload backups of your configuration.
- Third Party Code: [Package search](https://github.com/niksingh710/nsearch?tab=readme-ov-file) (can't be moved to default.nix)

### Installation Instructions

You can install `nixedit` using the provided `default.nix` file.

#### Environment:

Clone this repository to build and install the package. Copy & Paste.

```
mkdir ~/.nixedit; cd ~/.nixedit
git clone https://github.com/fndov/nixedit.git .
nix-build            # Build nixedit
nix-env -i ./result  # Install pacakge
```
```
# Uninstall package using:
nix-env --uninstall nixedit
```
#### Configuration:
Step 1. Clone this repository.
```
mkdir ~/.nixedit; cd ~/.nixedit
git clone https://github.com/fndov/nixedit.git .
```
Step 2. Include in your configuration.nix
```
nixpkgs.config.packageOverrides = pkgs: {
nixedit = pkgs.callPackage /home/USERNAME/.nixedit/default.nix { };
};

environment.systemPackages = with pkgs; [
nixedit
];
```
Step 3. Install the package.
```
sudo nixos-rebuild switch
