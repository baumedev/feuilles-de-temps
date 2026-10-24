# Feuilles de temps

Deux apps web (installables sur téléphone) qui partagent la même base de données :

- **Punch** (`punch.html`) : pour les gars au chantier. Juste entrer ses heures, vite, au cellulaire.
- **Bureau** (`index.html`) : approuver, rapports par chantier, exports paie et QuickBooks, gestion.

Le but : que les heures arrivent propres dans QuickBooks pour facturer et suivre les coûts, ce que le punch de QuickBooks ne fait pas comme vous en avez besoin.

## App punch (les gars)

- Écran d'accueil : « Salut Denis ! », les heures d'aujourd'hui, un gros bouton **Punch mes heures**, et la semaine en un coup d'œil
- Punch en 3 étapes, une question à la fois :
  1. **Où ?** Aujourd'hui, hier ou une autre date, puis le chantier (le dernier utilisé en premier)
  2. **Quoi ?** Code de coût (recherche par mot ou par numéro, codes récents en haut), heures avec des boutons − / + et 4 / 8 / 9 / 10 h, facturable ou non, description. « + Ajouter un autre code de coût » pour une deuxième ligne
  3. **Vérifier et envoyer**
- Boutons **Maladie**, **Congé**, **Férié** pour marquer une journée non travaillée
- Toucher une entrée pour la corriger ou la supprimer (tant qu'elle n'est pas facturée)
- « Première fois ? Créer mon compte » avec le courriel que le bureau a entré

## App bureau

**Employés** (l'app bureau sert aussi à entrer des heures)
- Voient leur semaine, jour par jour
- Ajoutent des heures. Une entrée contient :
  - **Date** et **chantier / projet** (lié au client ou projet QuickBooks)
  - Une ou plusieurs lignes, chacune avec son **code de coût**, ses **heures**, son choix **facturable ou non** (par défaut selon le chantier) et sa propre **description** des travaux (obligatoire). Exemple : 01 30 00 Gestion de projet 4 h « Coordination des sous-traitants » + 01 11 00 Conception 4 h « Relevés et plans » dans la même entrée. Le bouton « + Ajouter un autre code de coût » ajoute une ligne
- Une entrée à plusieurs codes s'approuve, se refuse, se modifie et se verrouille d'un seul bloc. Dans les rapports, la paie et l'export QuickBooks, chaque ligne compte séparément sous son propre code
- Le chantier et le code de leur dernière entrée sont pré-remplis
- Voient si leurs heures sont en attente, approuvées, refusées (avec le motif) ou 🔒 dans QuickBooks
- Peuvent modifier ou supprimer leurs heures, même approuvées, **tant qu'elles ne sont pas transférées dans QuickBooks**. Une entrée approuvée qu'ils modifient retourne en attente d'approbation

**Administrateur** (toi)
- **Approbation** : la semaine de chaque employé, approuver ou refuser une entrée, tout un employé, ou toute la semaine d'un coup. Ajouter des heures pour quelqu'un qui a oublié
- **Rapports > Par chantier** : tu choisis un chantier et des dates (ton cycle de facturation) et tu obtiens le rapport : totaux, heures par code de coût, par employé, et le **détail jour par jour de qui a fait quoi** (employé, code, description, heures). Bouton **Imprimer / PDF** pour l'envoyer au client, et export CSV
- **Rapports > Tous les chantiers** : heures, facturables et coût de main-d'œuvre de tous les chantiers sur une période
- **Exports > Paie (Employeur D)** : total des heures approuvées par employé pour la période de paie, et fichier .xls à importer dans Employeur D
- **Exports > QuickBooks** : transfère les heures approuvées d'une période. Elles sont alors **verrouillées pour tout le monde**, puisqu'elles servent à facturer
- **Gestion** : chantiers (ajouter, archiver, **importer de QuickBooks**), codes de coût (activer, désactiver, ajouter), **employés (ajouter : nom, courriel facultatif, matricule, taux, rôle)**, paramètres Employeur D
- **Maladie / Congé / Férié** : visibles dans Approbation et dans Paie. C'est seulement un repère pour savoir pourquoi une journée n'a pas été travaillée : aucune heure, rien n'est envoyé à la paie ni à QuickBooks

### Le cycle d'une entrée

1. **En attente** : l'employé l'entre et peut la modifier
2. **Approuvée** : tu l'approuves. L'employé peut encore la modifier, mais elle retourne alors en attente
3. **🔒 QuickBooks** : tu la transfères. Plus personne ne peut la modifier ni la supprimer (heures, chantier, code, description et facturable sont tous figés). Si une correction est vraiment nécessaire, ouvre l'entrée et touche **Annuler le transfert**. Pense à corriger aussi dans QuickBooks

Ces règles sont appliquées dans la base de données elle-même, pas seulement dans l'app.

> **Attention avec la paie.** Le verrouillage se fait au transfert QuickBooks, pas à l'export Employeur D. Si un gars modifie ses heures après que tu as fait la paie, l'entrée retourne en attente : tu le verras dans Approbation. L'idéal est de transférer à QuickBooks en même temps que tu fais la paie.

## Fichiers

| Fichier | Rôle |
|---|---|
| `punch.html` | App punch (les gars) |
| `index.html` | App bureau |
| `config.js` | **Les deux valeurs Supabase**, partagées par les deux apps |
| `schema.sql` | Tables et règles de sécurité à installer dans Supabase |
| `manifest*.json`, `sw.js`, `icone*` | Permettent d'installer les apps sur l'écran d'accueil du téléphone |

## Mise à jour d'une installation existante

Si tu as déjà installé une version précédente :
1. Recolle `schema.sql` au complet dans **SQL Editor** et clique **Run**. Tes données et tes comptes sont conservés.
2. Téléverse tous les fichiers sur GitHub. **Les valeurs Supabase sont maintenant dans `config.js`** : recopie-y les deux valeurs que tu avais mises dans `index.html`.
3. Dans Supabase, **active** « Allow new users to sign up » (voir l'étape 1.3 plus bas).

Les entrées faites avant l'ajout des codes de coût restent là, avec la mention « Sans code ». Sur une base déjà installée, l'équipe de départ n'est pas ajoutée : ajoute les employés manquants dans **Gestion > Employés**.

## Installation (environ 20 minutes)

### 1. Créer le projet Supabase
1. Sur supabase.com, **New project** (un projet neuf, séparé de Baume). Région : Canada (Central) si offerte.
2. Dans **SQL Editor > New query**, colle tout le contenu de `schema.sql` et clique **Run**.
3. Dans **Authentication > Sign In / Providers** : laisse **Allow new users to sign up** activé. C'est sans danger : la base refuse tout courriel qui n'a pas été entré par le bureau dans **Gestion > Employés**. Puis clique sur **Email** et **désactive « Confirm email »** : le service de courriel gratuit de Supabase n'envoie qu'aux membres de ton projet Supabase (2 courriels par heure), donc les gars ne recevraient jamais le courriel de confirmation.
4. Dans **Authentication > URL Configuration**, mets l'adresse de l'app punch comme **Site URL** (ex. `https://tonnom.github.io/feuilles-de-temps/punch.html`) et ajoute aussi `.../index.html` dans **Redirect URLs**.

### 2. Configurer les apps
Ouvre `config.js` et colle les deux valeurs de **Project Settings > API** :
- `SUPABASE_URL` : Project URL
- `SUPABASE_ANON_KEY` : la clé **anon / public** (jamais la clé `service_role`)

### 3. Mettre en ligne sur GitHub Pages
1. Nouveau dépôt GitHub (ex. `feuilles-de-temps`), téléverse tous les fichiers.
2. **Settings > Pages > Deploy from a branch > main / root**.

### 4. Créer les comptes
L'équipe de départ est déjà dans la base : **Victor** (administrateur), **Denis**, **Edouard**, **Guewenn** et **Guilhem**.
1. **Toi en premier** : ouvre l'app bureau, touche **Créer mon compte** et utilise ton courriel. Le tout premier compte créé est lié à Victor, l'administrateur.
2. **Gestion > Employés** : pour chaque gars, entre son **courriel** (pour qu'il puisse se créer un compte), son **matricule Employeur D** et son **taux horaire**. Tu peux aussi ajouter un employé avec **+ Ajouter un employé**.
3. Chaque gars ouvre l'app punch, touche **Première fois ? Créer mon compte** et utilise le courriel que tu as entré. Un courriel qui n'est pas dans la liste est refusé.
4. Un employé sans courriel existe quand même : tu peux entrer ses heures pour lui dans **Approbation**.
5. **Gestion > Paramètres** : numéro de compagnie et code de gain Employeur D.
6. **Gestion > Chantiers > Importer de QuickBooks** : importe ta liste de clients/projets (voir plus bas), ou ajoute tes chantiers un par un.
7. **Gestion > Codes** : vérifie la liste. Les 51 codes de ta nomenclature sont déjà chargés.

### 5. Installer sur les téléphones
Les gars ouvrent l'adresse de l'app punch (`.../punch.html`), toi celle du bureau (`.../index.html`), puis :
- **iPhone** (Safari) : bouton Partager > **Sur l'écran d'accueil**
- **Android** (Chrome) : menu ⋮ > **Installer l'application**

## Paie Employeur D

1. **Approbation** : approuve la semaine.
2. **Exports > Paie (Employeur D)** : choisis la période. La **date de fin doit être le dernier jour de ta période de paie dans Employeur D**, sinon l'import échoue.
3. **Télécharger le fichier Employeur D (.xls)**.
4. Dans Employeur D : **Paie > Outils > Importer les transactions**, format **Excel (en colonnes)**, choisis le fichier. Vérifie dans **Paie > Calendrier de paie courant**.

> **À valider au premier essai.** Les colonnes du fichier (No compagnie, Matricule, Période, Code de gain, Heures) sont une première version. Télécharge le **« Canevas d'importation – Transaction de paie »** dans l'aide d'Employeur D et compare. S'il faut changer l'ordre ou le format, c'est la liste `COLONNES_EMPLOYEUR_D` au début du script dans `index.html`. Fais un premier test sur une paie que tu vérifies à la main.

## Codes de coût

La nomenclature fournie (51 codes, de 01 Exigences générales à 99 Autres) est chargée automatiquement. Cinq codes qui ne correspondent pas à des heures travaillées sont **désactivés au départ** pour ne pas encombrer la liste des gars : 01 21 00 Contingence, 01 29 00 Acomptes, 01 31 00 Assurance, 01 52 13 Location de toilette et 01 54 00 Location d'équipements. Tu peux les réactiver, en désactiver d'autres ou en ajouter dans **Gestion > Codes**.

## Coûts de chantier

Coût de main-d'œuvre = heures × taux horaire **actuel** de l'employé, sans charges sociales (CNESST, RRQ, AE, etc.). Si tu changes un taux, les rapports passés sont recalculés avec le nouveau taux.

## QuickBooks

### Lier les chantiers aux clients/projets QuickBooks

Chaque chantier a un champ **« Client/projet dans QuickBooks »** : le nom exact tel qu'il apparaît dans QuickBooks, par exemple `Dupont:Rénovation cuisine` pour un projet ou un sous-client.

Le plus rapide est d'importer la liste :
1. Dans QuickBooks : **Ventes > Clients**, puis l'icône **Exporter vers Excel** au-dessus de la liste.
2. Dans l'app : **Gestion > Chantiers > Importer de QuickBooks**, choisis le fichier.
3. Coche les clients/projets qui sont des chantiers. Pour un projet, le nom du chantier devient le nom du projet et le client devient le parent. Un chantier existant qui porte le même nom est simplement associé.

> **À valider au premier essai.** L'import reconnaît la colonne « Client », « Customer » ou « Nom ». Si ton export QuickBooks est différent et que l'import ne trouve rien, envoie-moi le fichier et j'ajuste. Si tes projets n'apparaissent pas dans cet export, entre leur nom QuickBooks à la main dans chaque chantier.

### Transférer les heures

**Pour l'instant**, **Exports > QuickBooks > Transférer** verrouille les heures et télécharge un fichier : date, employé, client/projet QuickBooks, chantier, code de coût, heures, facturable, description de la ligne. Tu entres ces heures dans QuickBooks avec **+ Nouveau > Feuille de temps hebdomadaire**, sur le bon client ou projet. L'app t'avertit si un chantier n'est pas encore associé à QuickBooks.

**Prochaine étape : connexion directe.** Le même bouton enverra les heures directement dans QuickBooks. La base est déjà prête (colonnes `qbo_customer_id`, `qbo_employee_id`, `qbo_time_activity_id`). Il restera à :
1. Créer un compte développeur Intuit et une app (clés OAuth)
2. Ajouter une fonction Supabase (Edge Function) qui gère la connexion à QuickBooks et envoie les heures approuvées comme « activités de temps » sur le bon client ou projet
3. Remplacer le nom QuickBooks de chaque chantier par son identifiant QuickBooks (la liste se synchronisera alors toute seule), et associer chaque employé au sien
4. Associer chaque code de coût à un **produit/service** QuickBooks (colonne `qbo_item_id` déjà prévue), pour que le code suive les heures jusque sur la facture

## Mot de passe oublié

Le courriel de réinitialisation ne part pas aux employés (même limite du courriel gratuit de Supabase). Si un gars oublie son mot de passe : Supabase > **Authentication > Users**, menu « … » sur sa ligne > **Delete user**. Il refait **Créer mon compte** avec le même courriel : son profil et toutes ses heures sont conservés.
