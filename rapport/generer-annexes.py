#!/usr/bin/env python3
# Génère rapport/chapitres/annexe-preuves.tex et annexe-journal.tex à partir du dossier technique
# (source unique : « InfraReady - Dossier technique.md », sections Matrice des preuves et Journal de changements).
import re, pathlib
racine = pathlib.Path(__file__).resolve().parent.parent
md = (racine / "InfraReady - Dossier technique.md").read_text(encoding="utf-8")

def tex(cellule):
    """Markdown d'une cellule → LaTeX : `code` → \\code{}, liens → texte, caractères spéciaux échappés."""
    cellule = re.sub(r"\[([^\]]+)\]\([^)]*\)", r"\1", cellule)          # liens Markdown → libellé
    cellule = cellule.replace("**", "")
    morceaux = re.split(r"(`[^`]*`)", cellule)
    sortie = []
    for m in morceaux:
        if m.startswith("`") and m.endswith("`") and len(m) > 1:
            c = m[1:-1].replace("%", " pourcent ").replace("#", "n°")
            sortie.append(r"\code{" + c + "}")
        else:
            for a, b in [("\\", r"\textbackslash{}"), ("&", r"\&"), ("%", r"\%"), ("#", r"\#"), ("_", r"\_"), ("$", r"\$"), ("~", r"\textasciitilde{}")]:
                m = m.replace(a, b)
            sortie.append(m)
    return "".join(sortie).strip()

def table(titre_section):
    bloc = md.split(titre_section, 1)[1]
    lignes = []
    for l in bloc.splitlines()[1:]:
        if l.startswith("#"):
            break
        if l.startswith("|") and not re.match(r"^\|\s*-", l):
            lignes.append([c.strip() for c in l.strip().strip("|").split("|")])
    return lignes[1:]  # sans l'en-tête

preuves = table("### Matrice des preuves")
out = [r"% Fichier généré par rapport/generer-annexes.py — ne pas modifier à la main",
       r"\begin{longtable}{@{}P{1.2cm}P{1.7cm}P{6.4cm}P{4.6cm}@{}}",
       r"\caption{Matrice des preuves (\code{docs/preuves/})}\label{tab:matrice}\\",
       r"\toprule \textbf{Preuve} & \textbf{Date} & \textbf{Contenu} & \textbf{Fichier(s)} \\ \midrule \endfirsthead",
       r"\toprule \textbf{Preuve} & \textbf{Date} & \textbf{Contenu} & \textbf{Fichier(s)} \\ \midrule \endhead",
       r"\bottomrule \endfoot"]
for p in preuves:
    if len(p) < 4: continue
    fichiers = ", ".join(re.findall(r"\(docs/preuves/([^)]+)\)", p[3]))
    # noms de fichiers sécables après chaque tiret (colonne étroite)
    fichiers = r" \newline ".join(r"\texttt{" + f.replace("_", r"\_").replace("-", r"-\allowbreak ") + "}" for f in fichiers.split(", ")) if fichiers else tex(p[3])
    out.append(rf"\preuve{{{tex(p[0])}}} & {tex(p[1])} & {tex(p[2])} & {{\scriptsize {fichiers}}} \\")
out.append(r"\end{longtable}")
(racine / "rapport/chapitres/annexe-preuves.tex").write_text("\n".join(out) + "\n", encoding="utf-8")

journal = table("### Journal de changements")
out = [r"% Fichier généré par rapport/generer-annexes.py — ne pas modifier à la main",
       r"\begin{longtable}{@{}P{2cm}P{6.3cm}P{3.4cm}P{2.6cm}@{}}",
       r"\caption{Journal des changements sur le laboratoire}\label{tab:journal}\\",
       r"\toprule \textbf{Date} & \textbf{Modification} & \textbf{Validation} & \textbf{Preuve / retour arrière} \\ \midrule \endfirsthead",
       r"\toprule \textbf{Date} & \textbf{Modification} & \textbf{Validation} & \textbf{Preuve / retour arrière} \\ \midrule \endhead",
       r"\bottomrule \endfoot"]
for j in journal:
    if len(j) < 5: continue
    out.append(rf"{tex(j[0])} & {tex(j[2])} & {tex(j[3])} & {{\small {tex(j[4])}}} \\")
out.append(r"\end{longtable}")
(racine / "rapport/chapitres/annexe-journal.tex").write_text("\n".join(out) + "\n", encoding="utf-8")
print(len(preuves), "preuves,", len(journal), "entrées de journal")
