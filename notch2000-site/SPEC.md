# Notch2000 · site vitrine

`index.html` est la référence : un seul fichier HTML, CSS et JS, sans dépendance, qui reproduit la maquette validée. À intégrer dans la stack du site (ou à livrer tel quel).

## Principe

La page est le haut d'un écran de Mac, dans le noir. Un seul objet : le notch, centré en haut. Aucun texte hors du notch. Le téléchargement vit dans le notch, qui se déplie au clic comme l'app.

## Palette

| Rôle | Valeur |
|---|---|
| Fond, notch | `#000000` |
| Barre de session, bouton | Clay `#D97757` |
| Faisceau, cœur chaud | `#F6A98C` |
| Point KITT | `#FFF6EE` |
| Texte | Ivory `#FAF9F5` (62 % tagline, 45 % méta, 42 % chiffres) |
| Texte du bouton | `#141413` |

## Notch

| État | Largeur | Hauteur | Rayon bas |
|---|---|---|---|
| Repos | 320 px | 48 px | 16 px |
| Survol | 440 px | 48 px | 16 px |
| Ouvert | 560 px | 344 px | 32 px |

- Transition : 380 ms, `cubic-bezier(.2, .9, .25, 1.04)` (léger rebond).
- Épaules concaves de 12 px en haut à gauche et à droite.
- Survol : chiffres « 62% » et « 16:40 », mono 13 px light, 42 % d'opacité, fondu 180 ms. Le point KITT disparaît.
- Clic : panneau avec wordmark, tagline, bouton « Télécharger pour macOS », ligne de méta. Apparition 260 ms après 160 ms.
- Fermeture : clic hors du notch ou Échap.

## Barre de session (bord bas du notch)

- 3 px, pleine largeur, découpée par les arrondis. Partie non consommée : noire.
- Lueur : `0 0 5px rgba(217,119,87,.9), 0 0 14px rgba(217,119,87,.5)`.
- Point KITT : 8 × 3 px à la position du temps écoulé (47 % dans la démo).

## Séquence de chargement

| Temps | Événement |
|---|---|
| 0 → 2,4 s | Balayage K2000 : segment lumineux de 40 px, 2 allers (1,2 s chacun), barre vide |
| 2,4 s | Le balayage s'éteint (200 ms) |
| 2,5 → 3,4 s | La barre se remplit jusqu'à 62 % (900 ms, `cubic-bezier(.2,.8,.2,1)`) |
| 3,3 s | Le point KITT apparaît (300 ms) |

Le faisceau est présent dès le départ, sans fondu.

## Faisceau

Trapèze de lumière qui part du bord bas du notch et s'élargit jusqu'en bas de la page. Trois couches découpées par le même `clip-path` :

1. Halo flou (`blur(28px)`) : dégradé vertical Clay 34 % → 12 % → 0.
2. Cœur net : `#F6A98C` 20 % → Clay 6 % → 0.
3. Lignes de balayage horizontales : 1 px noir à 45 % tous les 4 px.

Plus une flaque elliptique floue au bas de la page (Clay 16 %).

| État | Demi-largeur en haut | Haut | Demi-largeur en bas |
|---|---|---|---|
| Repos | 160 px | 48 px | min(560 px, 45vw) |
| Survol | 220 px | 48 px | idem |
| Ouvert | 280 px | 344 px | min(700 px, 55vw) |

Les trois valeurs sont des propriétés CSS enregistrées (`@property`) pour que la transition du trapèze suive celle du notch (380 ms, même courbe).

## Accessibilité

- Le notch est un vrai `<button>` avec `aria-expanded`.
- Échap referme.
- `prefers-reduced-motion` : pas de balayage ni d'animation de remplissage, états sans transition.

## À compléter

- Police de marque : Michroma est provisoire, remplacer par la police racing retenue (classe `.wordmark`).
- Lien de téléchargement, version, macOS minimum, taille.
- Comportement mobile (non maquetté).
