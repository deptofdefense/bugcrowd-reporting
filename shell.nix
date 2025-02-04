{
  pkgs ? import <nixpkgs> { },
}:
with pkgs;
mkShell {
  buildInputs = [
    python312Packages.virtualenv
  ];

  shellHook = ''
    [[ ! -d .venv ]] && python -m venv .venv
    source .venv/bin/activate
    if [[ -f requirements.txt ]]; then
      pip install -r requirements.txt --require-virtualenv
    fi
  '';

  packages = [
    fzf
    jq
    (python312.withPackages (pythonPackages: [

    ]))
  ];
}
