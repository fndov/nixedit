{ pkgs ? import <nixpkgs> { } }:

pkgs.stdenv.mkDerivation {
  pname = "nixedit";
  version = "0.9";

  src = ./src;

  nativeBuildInputs = [
    pkgs.makeWrapper
  ];

  buildInputs = [
    pkgs.bash
    pkgs.fzf
    pkgs.jq
    pkgs.micro
    pkgs.git
  ];

  installPhase = ''
    mkdir -p $out/bin

    # Copy the scripts
    cp nixedit.sh $out/bin/nixedit

    # Ensure they are executable
    chmod +x $out/bin/nixedit

    # Wrap nixedit to include the necessary dependencies in PATH
    wrapProgram $out/bin/nixedit --prefix PATH : \
      "${pkgs.bash}/bin:${pkgs.fzf}/bin:${pkgs.jq}/bin:${pkgs.micro}/bin:${pkgs.git}/bin"
  '';

  meta = with pkgs.lib; {
    description = "A NixOS Rebuilding CLI Utility";
    license = licenses.mit;
    maintainers = [ maintainers.miyu ];
  };
}
