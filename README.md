## Nixedit
NixOS Multipurpose CLI/TUI Utility.
### Features:
- Full Terminal User Interface & Command line usage.
- Search Configure Build Backup Update Delete Optimise in one step.
- Complete Profile management, Integrated Creation & Removal. 
- Integrates with Github to upload backups of your configuration.
### TODO List for 1.2.0 release.
- [ ] Implement Python3.
- [ ] Implement functionality for seconds, minutes, and hours (Sec, Min & Hr).
- [ ] Consider other formats for the messages.
- [ ] Use `--upgrade` by default or make it an optional flag.
- [ ] Option to name your backups or add descriptions.

### Commands:
```
Settings:
  sync        Connect your dedicated GitHub repository to store backups

Info commands:
  help          Show this help message and exit
  version       Display current nixedit version

Terminal user interface:
  tui           Open dialog  

Singular options: (some have short options '-i') 
  search        Search packages
  configure     Open configuration
  add           Add package to configuration
  remove        Remove package from configuration
  install       Install package to systems
  uninstall     Uninstall package from system
  upload        Upload configuration
  update        Update system and database
  rebuild       Rebuild system and switch
  build         Build system and not switch
  profile       List existing profiles
  generation    List existing generations
  collect       Collect packages & profiles
  optimise      Optimize Nix storage
  graph         Browse dependency graph
  find          Find local packages
        
If no option is provided, the default operation will:
  - Perform a search
  - Open the configuration file for editing
  - Update channel
  - Rebuild the system
  - Upload configuration
  - Collect outdated packages
  - Optimise package storage
```
### Installation Instructions
You can install `nixedit` using the provided `package.nix` file.
#### Configuration:
Step 1. Clone this repository.
```
mkdir ~/.nixedit; cd ~/.nixedit
git clone https://github.com/fndov/nixedit.git .
```
Step 2. Include in your configuration.nix
```
nixpkgs.config.packageOverrides = pkgs: {
  nixedit = pkgs.callPackage /home/USERNAME/.nixedit/package.nix { };
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
Github: [Managing your personal access tokens](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/managing-your-personal-access-tokens). Use 'debug' for any problems, or submit an issue.

Third Party Code: [Package search](https://github.com/niksingh710/nsearch?tab=readme-ov-file)

<sup>experiments unsupported.<sup>
