# The eggceptionnal Chicken Norris : tutoriel clavier / souris

Tu incarnes Chicken Norris, une poule armée qui défend son poulailler contre les ennemis. Ta vie et celle du poulailler sont affichées à l'écran. Si l'une des deux tombe à 0, la partie est perdue.

## 1. Déplacement

| Action | Touche |
|---|---|
| Aller en haut | Z |
| Aller à gauche | Q |
| Aller en bas | S |
| Aller à droite | D |

Ce sont les touches ZQSD de la disposition AZERTY, placées sur les mêmes positions physiques que sur un clavier QWERTY.

## 2. Viser et tirer à l'arme

- **Viser** : bouge la souris. Chicken Norris regarde toujours vers le curseur dès que tu bouges la souris (ou que tu cliques).
- **Tirer** : clic gauche, maintenu pour tirer en continu.

## 3. Changer d'objet

Les trois objets sont dans la barre en bas au centre : **eggrenade**, **eggder pearl** et **egg bomba**. L'objet sélectionné est au milieu, plus grand, et son nom s'affiche au-dessus.

- **Molette vers le haut** : objet précédent.
- **Molette vers le bas** : objet suivant.

Le nombre d'exemplaires de chaque objet est affiché dans sa case. Un objet épuisé est grisé.

## 4. Lancer un objet (lance-pierre)

1. **Maintiens le clic droit** : le zoom s'adapte pour voir la cible, et un élastique s'affiche entre le point de départ et ta souris.
2. **Tire la souris** dans la direction *opposée* à celle où tu veux envoyer l'objet. Par exemple, pour lancer vers la gauche, tire vers la droite.
3. **Plus la traction est longue, plus l'objet va loin** (sa portée est plafonnée).
4. Un arc montre où l'objet va tomber.
5. **Clic gauche** pour lancer. Le zoom reste actif jusqu'à ce que tu relâches le clic droit.
6. **Relâcher le clic droit sans valider** annule le lancer.

Le clic gauche ne tire pas à l'arme pendant la visée.

## 5. Les objets

- **eggrenade** : explose à son point de chute et inflige des dégâts aux ennemis proches.
- **eggder pearl** : te téléporte au point visé, si la place est libre.
- **egg bomba** : explose après un court délai et élimine tous les ennemis dans son rayon.

Pour récupérer un objet au sol, marche simplement dessus. Il s'ajoute à ton inventaire.

## 6. Fumer le joint (récupérer de l'endurance)

Le joint en haut à gauche se consume lentement, en 45 secondes. Quand il est vide, Chicken Norris perd 5 points de vie toutes les 2 secondes.

Pour le remonter, ouvre le **mini-jeu de rythme** :

- **Touche A** : ouvre le mini-jeu. Appuie à nouveau sur A pour le fermer.
- Une ligne horizontale apparaît, et des touches arrivent vers la cible.
- **Touches 1, 2, 3, 4** : les quatre voies, dans l'ordre de l'affichage.
- Une bonne touche au bon moment ajoute **5 secondes** au joint, sans dépasser 45 secondes.
- Une mauvaise touche ou un appui trop tôt ne fait rien.
- Le mini-jeu se ferme tout seul quand le joint est plein.

Le mini-jeu n'est disponible que lorsque le joint n'est pas plein.

## 7. Les barres à l'écran

- **Joint** : en haut à gauche. Avec la fumée qui s'en échappe.
- **Chicken Norris** : sa barre de vie, sous le joint, avec le cœur qui se vide.
- **Poulailler** : sa barre de vie, juste en dessous.
- **Boussole** : quand le poulailler est hors de l'écran, une flèche sur le bord de l'écran indique sa direction.

## 8. Fin de partie

- Si **Chicken Norris** tombe à 0 point de vie : « Chicken Norris est mort ».
- Si le **poulailler** tombe à 0 point de vie : « Le Poulailler a été détruit par les envahisseurs ».

Dans les deux cas, **Play again** relance la partie.
