## Nixedit
NixOS build automating utility, for your Configuration & System.
### Features:
- Full Terminal User Interface & Command line usage.
- Search Configure Build Backup Update Delete Optimise in one step.
- Integrates with Github to upload backups of your configuration.

## Screenshot
![Screenshot_20241006_141441](https://github.com/user-attachments/assets/023dfac6-7849-4c37-b06d-5c99a8f75faa)
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
```
---
Github: [Managing your personal access tokens](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/managing-your-personal-access-tokens). Use ``--debug`` for any problems, or submit an issue.

Third Party Code: [Package search](https://github.com/niksingh710/nsearch?tab=readme-ov-file)

<sup>*experiments unsupported.*<sup>
