#!/bin/bash
# Compile le rapport final (LuaLaTeX) dans un conteneur TeX Live, depuis la racine du dépôt.
# usage : ./rapport/build.sh            → InfraReady-Rapport-final.pdf à la racine
#         ./rapport/build.sh diagrammes → régénère aussi les schémas (rapport/diagrammes/*.mmd → rapport/figures/*.pdf)
set -euo pipefail
cd "$(dirname "$0")/.."
if [ "${1:-}" = diagrammes ]; then
  for f in rapport/diagrammes/*.mmd; do
    n=$(basename "$f" .mmd)
    docker run --rm -u "$(id -u):$(id -g)" -v "$PWD/rapport:/data" minlag/mermaid-cli:11.4.2 \
      -i "/data/diagrammes/$n.mmd" -o "/data/figures/$n.pdf" -f -b white -q
    echo "schéma : $n"
  done
fi
docker run --rm -u "$(id -u):$(id -g)" -e HOME=/tmp -v "$PWD:/doc" -w /doc texlive/texlive:latest-medium \
  latexmk -lualatex -interaction=nonstopmode -halt-on-error -outdir=rapport/build InfraReady-Rapport-final.tex
cp rapport/build/InfraReady-Rapport-final.pdf .
echo "PDF : InfraReady-Rapport-final.pdf ($(du -h InfraReady-Rapport-final.pdf | cut -f1))"
