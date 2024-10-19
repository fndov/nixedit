{
  lib,
  stdenv,
  fetchFromGitHub,
  bash,
  fzf,
  jq,
  micro,
  git,
  nix-tree,
  coreutils,
  makeWrapper,
  dialog,
}:

stdenv.mkDerivation {
  pname = "nixedit";
  version = "1.0.0";

  src = ./src;

  nativeBuildInputs = [
    makeWrapper
  ];

  buildInputs = [
      bash
      fzf
      jq
      micro
      git
      nix-tree
      coreutils
      dialog
    ];

  installPhase = ''
    mkdir -p $out/bin

    # Copy the scripts
    cp src/nixedit.sh $out/bin/nixedit

    # Ensure they are executable
    chmod +x $out/bin/nixedit

    # Wrap nixedit to include the necessary dependencies in PATH
    wrapProgram $out/bin/nixedit --prefix PATH : \
      "${bash}/bin:${coreutils}/bin:${nix-tree}/bin:${jq}/bin:${micro}/bin:${git}/bin:${fzf}/bin:${dialog}/bin"
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    if ! uname -a | grep "NixOS" > /dev/null; then
      echo "This package can only be installed on NixOS."
      exit 1
    fi

    $out/bin/nixedit --help > /dev/null
  '';

  meta = {
    homepage = "https://github.com/fndov/nixedit";
    description = "A NixOS Multipurpose CLI/TUI Utility";
    license = lib.licenses.gpl3;
    mainProgram = "nixedit";
    maintainers = with lib.maintainers; [ miyu ];
  };
}
