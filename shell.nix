{
  pkgs ? import <nixpkgs> { },
}:
with pkgs;
mkShell {
  buildInputs = [ ];

  shellHook = ''
    # Use Mac's sed
    alias sed=/usr/bin/sed
  '';

  packages = [
    fzf
    jq
    parallel
    miller
  ];
}
