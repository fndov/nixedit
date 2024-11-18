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
  version = "1.1.0";

  src = fetchFromGitHub {
    owner = "fndov";
    repo = "nixedit";
    rev = "388013c0e762027905b079e3fe89d44dfc495d09";
    hash = "sha256-s+xFakiKODAPEDQCEo0JudQBrVQr6Br7OzBN5JoMOnE=";
  };

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

    mv src/nixedit.sh $out/bin/nixedit

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
    description = "NixOS Multipurpose CLI/TUI Utility";
    license = licenses.gpl3;
    mainProgram = "nixedit";
    maintainers = with maintainers; [ miyu ];
    platforms = lib.platforms.linux;
  };
})
