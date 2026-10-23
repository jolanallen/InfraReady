-- Rend le code en ligne sécable : imprime la chaîne avec les codes de catégorie « autre »
-- et autorise une coupure de ligne après _ / . - ainsi qu'entre une minuscule et une
-- majuscule (noms en CamelCase), utile dans les colonnes étroites des tableaux.
function codesecable(s)
  local precedent = ""
  for c in string.gmatch(s, utf8.charpattern) do
    if precedent:match("^[a-z]$") and c:match("^[A-Z]$") then
      tex.sprint("\\allowbreak{}")
    end
    tex.sprint(-2, c)
    if c:match("^[_/%.%-]$") then
      tex.sprint("\\allowbreak{}")
    end
    precedent = c
  end
end
