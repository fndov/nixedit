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

stdenv.mkDerivation (finalAttrs: {
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
    runHook reInstall

    mkdir -p $out/bin

    mv nixedit.sh $out/bin/nixedit

    chmod +x $out/bin/nixedit

    runHook postInstall
  '';

  postFixup = ''
    wrapProgram $out/bin/nixedit \
      --prefix PATH : "${lib.makeBinPath finalAttrs.buildInputs}"
  '';

  installCheckPhase = ''
    if ! uname -a | grep "NixOS" > /dev/null; then
      echo "nxiedit package can only be installed on NixOS."
      exit 1
    fi
  '';

  meta = with lib; {
    homepage = "https://github.com/fndov/nixedit";
    description = "A NixOS Multipurpose CLI/TUI Utility";
    license = licenses.gpl3;
    mainProgram = "nixedit";
    maintainers = with maintainers; [ miyu ];
    platforms = lib.platforms.linux;
  };
})
