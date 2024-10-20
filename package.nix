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

  src = fetchFromGitHub {
    owner = "fndov";
    repo = "nixedit";
    rev = "00cfa46fdaa7075c1253de5b9e05e7703150b53f";
    hash = "sha256-jdQ3GK+7Ew3mifmChc95sYv0zOID3SkFIjxPOtzCu7Q=";
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
    description = "A NixOS Multipurpose CLI/TUI Utility";
    license = licenses.gpl3;
    mainProgram = "nixedit";
    maintainers = with maintainers; [ miyu ];
    platforms = lib.platforms.linux;
  };
})
