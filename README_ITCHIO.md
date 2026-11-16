# Publication Web sur itch.io

Fichier à envoyer : `builds/chicke-norris-itchio.zip`.
Il contient `index.html` à la racine et tous les fichiers nécessaires au jeu.
Ne pas envoyer le dossier du projet Godot ni les modèles d'export.

## Réglages itch.io

1. Connecte-toi sur https://itch.io/game/new ou modifie la page du jeu.
2. Choisis **Kind of project : HTML** (jeu jouable dans le navigateur).
3. Dans **Uploads**, envoie `chicke-norris-itchio.zip`.
4. Coche **This file will be played in the browser** pour ce fichier.
5. Dans **Embed options**, choisis **Click to launch in fullscreen**.
   Pour intégrer le jeu dans la page, utilise par exemple **1152 × 648**
   avec **Fullscreen button** et **Click to Play** activés.
6. Laisse **SharedArrayBuffer support** désactivé : cet export fonctionne sans threads.
7. Laisse **Mobile friendly** désactivé : les commandes sont prévues pour
   clavier/souris ou manette, sans boutons tactiles.
8. Ajoute le titre, la description, les commandes, les crédits et les captures.
9. Clique sur **Save & view page**, teste la version hébergée, puis passe
   **Visibility & access** à **Public** lorsque tu veux publier.

Guide officiel : https://itch.io/docs/creators/html5

## Démarrer et jouer

Sur ordinateur, clique dans le jeu pour activer le son et lui donner le focus.
Pour jouer à la manette, branche-la puis appuie sur un bouton pour permettre
au navigateur de la détecter. **A** ou **Start** démarre la partie.
Une manette physique reste à tester sur la page itch.io avec ton navigateur.

| Action | Clavier / souris | Manette Xbox |
| --- | --- | --- |
| Déplacement | ZQSD / WASD selon le clavier | Stick gauche |
| Viser / tirer | Souris / clic gauche | Stick droit / RT |
| Choisir un objet | Molette | LB / RB |
| Viser avec un objet | Maintenir clic droit | Maintenir LT |
| Utiliser l'objet visé | Clic gauche | RT |
| Ouvrir / fermer le mini-jeu | A | Croix directionnelle haut |
| Notes du mini-jeu | 1, 2, 3, 4 | Y, X, A, B |
| Confirmer un dialogue | Entrée / clic gauche | A |

## Réexporter après des modifications

Le préréglage **Web - itch.io** est enregistré dans `export_presets.cfg`.
Les modèles officiels Godot **4.7.2** sont dans `builds/templates/`.
Ces fichiers sont locaux et ne sont pas suivis par Git.

Dans Godot : **Projet → Exporter → Web - itch.io → Exporter le projet**,
décoche **Exporter avec débogage**, puis conserve le chemin
`builds/web/index.html`.

Ou, depuis la racine du projet :

```sh
godot --headless --path . --export-release "Web - itch.io" builds/web/index.html
```

Recrée ensuite le ZIP avec les fichiers **à la racine**, sans dossier `web/` :

```sh
python3 - <<'PY'
from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED
web = Path('builds/web')
with ZipFile('builds/chicke-norris-itchio.zip', 'w', ZIP_DEFLATED, compresslevel=9) as archive:
    for file in sorted(web.iterdir()):
        if file.is_file() and not file.name.startswith('.'):
            archive.write(file, file.name)
PY
```

Pour tester localement, ne double-clique pas sur `index.html` : lance
`python3 -m http.server 8000 --directory builds/web`, puis ouvre
http://localhost:8000 dans ton navigateur.

Le rendu Compatibility et la résolution de référence 1920 × 1080 sont
configurés uniquement pour l'export Web. Le jeu s'adapte à la taille du cadre.
Documentation Godot : https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_web.html
