{ pkgs ? import <nixpkgs> {} }:

pkgs.stdenv.mkDerivation {
  pname = "nixedit";
  version = "1.0";

  src = ./src;

  nativeBuildInputs = [
    pkgs.bash
    pkgs.nix-tree
    pkgs.fzf
    pkgs.jq
    pkgs.micro
    pkgs.git
    ];

  installPhase = ''
    mkdir -p $out/bin
    mkdir -p $out/lib/nixedit  # Create the directory for nsearch.sh
    cp nixedit.sh $out/bin/nixedit
    cp nsearch.sh $out/lib/nixedit/nsearch
    chmod +x $out/bin/nixedit
    chmod +x $out/lib/nixedit/nsearch
  '';

  meta = with pkgs.lib; {
    description = "A NixOS Rebuilding CLI Utility";
    license = licenses.mit;
    maintainers = [ maintainers.yourname ];
  };
}
