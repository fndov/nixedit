## Nixedit
NixOS build automating utility, for your Configuration & System.
### Features:
- Full Terminal User Interface & Command line usage.
- Search Configure Build Backup Update Delete Optimise in one step.
- Integrates with Github to upload backups of your configuration.
### Commands:
```Nixedit Help
Settings:
  --github        Connect your dedicated GitHub repository to store backups

Info commands:
  --help          Show this help message and exit
  --version       Display current nixedit version

Terminal user interface:
  --tui           Open dialog  

Singular options: (some hame short options '"'-i'"') 
  --search        Search packages
  --configure     Open configuration
  --add           Add package to configuration
  --remove        Remove package from configuration
  --install       Install package to system
  --uninstall     Uninstall package from system
  --upload        Upload configuration
  --update        Update nixpkgs & search, databases
  --rebuild       Rebuild system
  --profile       List existing profiles
  --generation    List existing generations
  --delete        Delete older packages
  --optimise      Optimize Nix storage
  --graph         Browse dependency graph
  --find          Find local packages
        
If no option is provided, the default operation will:
  - Perform a search
  - Open the configuration file for editing
  - Update system packages
  - Rebuild the system
  - Upload configuration
  - Delete old packages
  - Optimise package storage
```
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
