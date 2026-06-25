# ProspectFlow CRM — Guide de déploiement

CRM cloud multi-utilisateurs avec comptes **admin** et **commerciaux**, données partagées, et permissions par **segment** (tu choisis quels leads chaque commercial peut voir).

**Stack :** Supabase (base de données + comptes + sécurité) + Vercel (hébergement + gestion des comptes). Les deux sont **gratuits** pour ton usage.

Compte ~20 minutes la première fois. Aucune compétence technique requise, juste du copier-coller.

---

## Ce que tu vas faire

1. Créer un projet **Supabase** (la base de données cloud)
2. Coller le SQL fourni (crée les tables + la sécurité)
3. Mettre tes 2 clés Supabase dans `index.html`
4. Déployer sur **Vercel** + ajouter la clé secrète
5. Créer ton compte admin, tes segments, tes commerciaux

---

## Étape 1 — Créer le projet Supabase

1. Va sur **https://supabase.com** → *Start your project* → connecte-toi (GitHub ou email).
2. *New project*. Donne un nom (ex : `crm-prospection`), choisis une région **Europe (Frankfurt ou Paris)**, et un mot de passe de base de données (note-le, peu importe). Crée.
3. Attends ~2 min que le projet soit prêt.

## Étape 2 — Installer la base de données

1. Dans Supabase, menu de gauche → **SQL Editor** → *New query*.
2. Ouvre le fichier **`supabase-setup.sql`** (fourni), copie **tout** son contenu, colle dans l'éditeur.
3. Clique **Run** (en bas à droite). Tu dois voir *Success*. ✅

## Étape 3 — Récupérer tes 2 clés et les mettre dans l'app

1. Dans Supabase → **Project Settings** (roue crantée) → **API**.
2. Note ces deux valeurs :
   - **Project URL** → ressemble à `https://abcd1234.supabase.co`
   - **anon public** (clé API, section *Project API keys*) → une longue chaîne `eyJ...`
3. Ouvre **`index.html`** avec un éditeur de texte (TextEdit, Notepad, VS Code…). Tout en haut du script, remplace :
   ```js
   const SUPABASE_URL = "https://TON-PROJET.supabase.co";
   const SUPABASE_ANON_KEY = "TA_CLE_ANON_PUBLIQUE";
   ```
   par tes vraies valeurs. Enregistre.

> La clé **anon** est *publique* par design : la sécurité est gérée côté serveur par les règles RLS. Aucun risque à la mettre dans le fichier.

> ⚠️ Ne mets **jamais** la clé `service_role` dans `index.html`. Elle va uniquement dans Vercel (étape 5).

## Étape 4 — (Recommandé) Désactiver la confirmation d'email

Pour que toi et tes commerciaux puissiez vous connecter immédiatement sans cliquer sur un email :

- Supabase → **Authentication** → **Providers** → **Email** → décoche **Confirm email** → Save.

(Si tu laisses activé, chaque nouveau compte devra confirmer via un lien email.)

## Étape 5 — Déployer sur Vercel

Le plus simple, sans rien installer :

1. Va sur **https://vercel.com** → connecte-toi (GitHub conseillé).
2. Mets le dossier **`crm-cloud`** (ce dossier complet) sur un dépôt GitHub, OU utilise *Vercel CLI* / le glisser-déposer. Le plus simple :
   - Installe l'app **GitHub Desktop**, crée un repo avec ce dossier, publie-le.
   - Sur Vercel → *Add New → Project* → importe ce repo → **Deploy**.
3. Une fois déployé, va dans **Settings → Environment Variables** du projet Vercel et ajoute :
   | Name | Value |
   |------|-------|
   | `SUPABASE_URL` | la même *Project URL* qu'à l'étape 3 |
   | `SUPABASE_SERVICE_ROLE_KEY` | la clé **service_role** (Supabase → Settings → API → *service_role*, **secrète**) |
4. **Redeploy** (onglet Deployments → … → Redeploy) pour que les variables soient prises en compte.

Ton CRM est en ligne à l'adresse `https://ton-projet.vercel.app` 🎉

> La fonction `/api/admin` (création/suppression des comptes) ne fonctionne **que** une fois déployée sur Vercel — c'est normal qu'elle ne marche pas si tu ouvres `index.html` en local.

## Étape 6 — Première connexion & configuration

1. Ouvre ton URL Vercel.
2. Onglet **« Créer compte admin »** → ton nom, email, mot de passe → crée. **Le tout premier compte devient automatiquement administrateur.**
3. Une fois connecté en admin :
   - **Segments** : crée tes segments (ex : *Restauration Paris*, *Grands comptes*, *Privé*). Range tes leads dedans. Un segment où tu ne coches aucun commercial reste **privé** (toi seul le vois).
   - **Utilisateurs** : *Créer un compte* pour chaque commercial (email + mot de passe que tu leur communiques).
   - Reviens dans **Segments** et coche, pour chaque segment, les commerciaux qui ont le droit de le voir.
   - **Importer** : choisis le segment de destination, glisse ton CSV/Excel. Seuls les nouveaux numéros sont ajoutés.

C'est prêt. Tes commerciaux se connectent avec l'URL + leurs identifiants et ne voient que les segments que tu leur as ouverts.

---

## Qui peut faire quoi

| Action | Admin | Commercial |
|---|---|---|
| Voir les leads | **Tous** | Seulement ses segments autorisés |
| Changer statut / appeler / noter / relancer | ✅ | ✅ (sur ses segments) |
| Ajouter un lead | ✅ | ✅ (dans un segment qu'il voit) |
| Importer en masse (CSV/Excel) | ✅ | ❌ |
| Supprimer un lead | ✅ | ❌ |
| Gérer les segments & accès | ✅ | ❌ |
| Créer / supprimer des comptes | ✅ | ❌ |
| Voir le CA et la perf de l'équipe | ✅ | ❌ (voit seulement ses chiffres) |

La sécurité est appliquée **côté base de données** (RLS Supabase) : un commercial ne peut techniquement pas accéder à un segment interdit, même en contournant l'interface.

---

## Questions fréquentes

**Les commerciaux peuvent appeler depuis leur téléphone ?**
Oui. Le bouton 📞 ouvre l'appli d'appel par défaut, 💬 ouvre WhatsApp. Sur mobile, ajoute l'URL Vercel à l'écran d'accueil → ça fait une vraie app.

**Comment répartir les leads entre commerciaux ?**
Deux leviers : (1) les **segments** (qui voit quoi), et (2) le champ **« Assigné à »** dans la fiche lead (pour la perf individuelle dans le dashboard admin).

**Mes données sont où ?**
Dans ta base Supabase (cloud européen si tu as choisi Frankfurt/Paris). Tu peux exporter en CSV à tout moment depuis la base de leads.

**C'est vraiment gratuit ?**
Oui pour démarrer : Supabase offre 500 Mo de base + 50 000 utilisateurs actifs/mois, Vercel offre l'hébergement perso gratuit. Largement suffisant pour une équipe commerciale.

---

Besoin d'un coup de main pour le déploiement ? Je peux te guider en direct dans ton navigateur, écran par écran.
