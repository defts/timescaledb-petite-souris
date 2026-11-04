# Guide de répétition — 30 minutes

Lis ce texte à voix haute en simulant les transitions de slides.
Chronomètre-toi. Objectif : finir en 28 minutes max.

---

## [SLIDE 1 — Titre] ⏱ 0:00

*Respire. Souris. Attends que la salle se pose.*

"Bonjour à tous, je suis David Torres Dias, et aujourd'hui je vais vous raconter comment la Petite Souris gère ses milliards de dents... avec TimescaleDB."

➡️ Slide suivante

## [SLIDE 2 — Qui suis-je ?] ⏱ 0:15

*Rapide, pas de bio complète, juste la crédibilité.*

"Développeur depuis 15 ans, utilisateur PostgreSQL depuis la 9.4, dev Go chez Karnott depuis 7 ans. Karnott c'est de l'agriculture connectée — des boîtiers GPS sur des tracteurs. On a 37 milliards de points de données en production sur TimescaleDB. C'est de là que vient mon expérience."

➡️ Slide suivante — **tu dois être à 0:30**

## [SLIDE 3 — C'est quoi TimescaleDB ?] ⏱ 0:30

*Poser les bases. Insister sur la simplicité.*

"TimescaleDB c'est une extension PostgreSQL. Pas un nouveau SGBD, pas de migration — juste `CREATE EXTENSION`. C'est open source, Apache 2.0 pour le core, TSL pour les features avancées. Utilisé par Cloudflare, le CERN, et nous chez Karnott.

Le concept clé c'est les hypertables. Vous créez une table normale, vous appelez `create_hypertable`, et PostgreSQL se charge du partitionnement automatique. Deux lignes de SQL."

*Petite remarque à l'oral : Timescale s'appelle maintenant TigerData depuis juin 2025, mais l'extension s'appelle toujours TimescaleDB.*

➡️ Slide suivante — **tu dois être à 1:30**

## [SLIDE 4 — Transition Petite Souris] ⏱ 1:30

*Sourire, break léger.*

"Bon, pour vous montrer tout ça concrètement, on va quitter les tracteurs... et parler de la Petite Souris !"

➡️ Slide suivante — **tu dois être à 1:40**

## [SLIDE 5 — Le cas de la Petite Souris SA] ⏱ 1:40

*Poser le contexte ludique mais réaliste.*

"Imaginez. 2 milliards d'enfants dans le monde. 20 dents de lait chacun. Des millions de transactions par nuit, avec un pic entre 6 et 12 ans. Les mêmes défis que chez Karnott : analyser des milliards de lignes, des requêtes temporelles complexes, et un stockage qui explose."

➡️ Slide suivante — **tu dois être à 2:10**

## [SLIDE 6 — Le schéma de données] ⏱ 2:10

*Prends ton temps ici, c'est la fondation de tout le reste.*

"À gauche, des tables de référence classiques — pays, dents, enfants. Rien de spécial.

À droite, LA table importante : `tooth_loss`. C'est notre hypertable. Elle a une colonne temporelle `collected_at` en TIMESTAMPTZ, des clés étrangères, et un prix.

Pour la transformer en hypertable, deux options. La forme simple : `create_hypertable` avec juste le nom de la table et la colonne de temps. Ça suffit souvent. La forme avancée : `by_range` pour contrôler la taille des chunks — ici 7 jours — et `add_dimension` pour ajouter un partitionnement spatial par pays. Double partitionnement : performance + compression optimale."

➡️ Slide suivante — **tu dois être à 3:40**

## [SLIDE 7 — Architecture des chunks] ⏱ 3:40

*Montrer le schéma, laisser les gens absorber.*

"Visuellement, voilà comment ça fonctionne. Les données arrivent, l'hypertable les répartit en chunks. Horizontalement, c'est le temps — les chunks vieillissent. Verticalement, c'est l'espace — 4 partitions par hash du pays. C'est ce double découpage qui rend la compression et les requêtes si efficaces."

➡️ Slide suivante — **tu dois être à 4:10**

## [SLIDE 8 — La solution : TimescaleDB] ⏱ 4:10

"Maintenant qu'on a notre hypertable, je vais vous montrer 4 fonctionnalités clés. En live."

➡️ Slide suivante

## [SLIDE 9 — Au programme] ⏱ 4:15 — ✅ CHECKPOINT < 5:00

*Balayage rapide des 4 colonnes, pas de détail.*

"Hyperfunctions — des fonctions qui n'existent pas dans PostgreSQL standard. Compression — 95% de réduction, automatique. Continuous aggregates — du pré-calcul 10 à 100 fois plus rapide. Et retention — suppression automatique, maintenance zéro. On y va."

➡️ Slide suivante — **tu dois être à 4:45**

## [SLIDE 10 — Transition DÉMO Hyperfunctions] ⏱ 4:45

"Première démo : les hyperfunctions."

➡️ Slide suivante

## [SLIDE 11 — Hyperfunctions] ⏱ 5:00 — ⏳ COUNTDOWN 6:00

*C'est ton moment fort. Prends le temps mais surveille le countdown.*

**Basculer sur DataGrip — script 01-hyperfunctions.sql**

1. **time_bucket** (~2 min)
   "D'abord, comment vous faites un GROUP BY par tranche de 30 minutes en PostgreSQL standard ? Ça. *montrer la requête extract/epoch*. Pas très lisible hein ? Avec TimescaleDB : `time_bucket('30 minutes', collected_at)`. C'est tout. Mais regardez le résultat — on a des trous. Il manque des créneaux."

2. **gapfill** (~1 min 30)
   "C'est là qu'arrive `time_bucket_gapfill`. Même requête, mais les trous sont remplis automatiquement. 48 lignes sur 48. Et bonus, ça marche avec les window functions — ici un cumul."

3. **stats_agg + percentiles** (~2 min 30)
   "Maintenant, les statistiques. En PostgreSQL standard, AVG, STDDEV, VARIANCE — ça marche, mais ça vous donne 3 colonnes séparées. Avec `stats_agg`, vous avez un seul objet agrégé. Vous pouvez le stocker dans une continuous aggregate et extraire ce que vous voulez après : average, stddev, variance... Et avec `percentile_agg`, des percentiles approximatifs ultra-rapides. P50, P90.

   Notez les deux syntaxes : le pipeline avec `->` et l'appel de fonction classique. Les deux marchent. Le pipeline vient de l'extension `timescaledb_toolkit`, à installer en plus."

**Revenir sur les slides**

➡️ Slide suivante — **tu dois être à ~11:00**

## [SLIDE 12 — Compression] ⏱ ~11:00 — ✅ CHECKPOINT < 12:00 — ⏳ COUNTDOWN 3:00

*Si tu es en retard, montre juste les stats globales et la requête sur données compressées.*

"Slide : voilà le code. Depuis TimescaleDB 2.18, c'est la nouvelle API columnstore. `enable_columnstore`, `segmentby` par pays, et une policy automatique. L'ancienne syntaxe est en commentaire pour référence."

**Basculer sur DataGrip — script 02-compression.sql**

"Les stats. *exécuter la première requête*. Regardez le gain. ~95% de compression. Chez Karnott, on est passé de 16 TB à 6 TB. 1 800 euros par mois économisés sur GCP.

Et le plus beau : les requêtes marchent exactement pareil sur les données compressées. *exécuter la requête sur données compressées*. Décompression transparente."

**Revenir sur les slides**

➡️ Slide suivante — **tu dois être à ~14:00**

## [SLIDE 13 — Continuous Aggregates] ⏱ ~14:00 — ✅ CHECKPOINT < 16:00 — ⏳ COUNTDOWN 3:00

*Le punch c'est la comparaison EXPLAIN ANALYZE.*

"Les continuous aggregates, c'est des vues matérialisées... mais en mieux. Elles se rafraîchissent automatiquement, et avec `materialized_only = false`, les données récentes sont agrégées en temps réel.

Ici j'utilise `stats_agg` et `percentile_agg` — les hyperfunctions qu'on vient de voir — directement dans la vue."

**Basculer sur DataGrip — script 03-caggs.sql**

"Requête sur la cagg : stats par jour pour la France. *exécuter*. Instantané.

Maintenant LE test. EXPLAIN ANALYZE sur la table brute vs sur la cagg. *exécuter les deux*. Regardez la différence de temps. Et les résultats sont quasi identiques — moins de 1% d'erreur sur les percentiles."

*Si le temps le permet : montrer le rollup pour cagg hiérarchique.*

**Revenir sur les slides**

➡️ Slide suivante — **tu dois être à ~17:00**

## [SLIDE 14 — Retention] ⏱ ~17:00 — ✅ CHECKPOINT < 20:00 — ⏳ COUNTDOWN 3:00

*Démo la plus simple, tu peux accélérer ici si besoin.*

"Dernière fonctionnalité : la rétention. Le RGPS — le Règlement Général des Petites Souris — *pause, sourire* — nous oblige à supprimer les données de plus de 3 ans.

En PostgreSQL standard, un DELETE sur des milliards de lignes, c'est lent et ça bloque. TimescaleDB ne supprime pas les lignes : il DROP le chunk entier. Instantané. Pas de VACUUM."

**Basculer sur DataGrip — script 04-retention.sql**

"L'état actuel des données. *exécuter*. Et voilà les chunks avec ce qui serait supprimé. Une seule ligne pour la policy : `add_retention_policy`, intervalle 3 ans. Maintenance zéro."

**Revenir sur les slides**

➡️ Slide suivante — **tu dois être à ~20:00**

## [SLIDE 15 — Transition REX Karnott] ⏱ ~20:00

"Bon, la Petite Souris c'est rigolo. Mais en vrai, tout ce que je viens de vous montrer, on l'utilise en production chez Karnott depuis des années."

➡️ Slide suivante

## [SLIDE 16 — REX Karnott détails] ⏱ ~20:30 — ✅ CHECKPOINT < 24:00

"Agriculture connectée. GPS sur des milliers d'engins agricoles. 37 milliards de points de données. 10 hypertables en prod. PostgreSQL 18 avec TimescaleDB 2.26 et PostGIS, sur Google Cloud Platform.

Nos cas d'usage : tracking temps réel, calcul de surfaces travaillées, répartition des travaux, alertes. Et notre problème initial : le stockage qui explosait et les coûts GCP qui grimpaient."

➡️ Slide suivante — **tu dois être à ~22:00**

## [SLIDE 17 — Les gains mesurés] ⏱ ~22:00

*Les chiffres parlent d'eux-mêmes. Laisser le temps de lire.*

"Les résultats. `device_event` : 4.6 téra réduits à 119 giga. 97.5% de compression. `location` : 5.9 téra à 394 giga. En moyenne sur nos 10 tables : 94.7%.

Le chiffre important : 16 TB ramenés à 6. 10 TB économisés. 1 800 euros par mois en moins sur la facture cloud. 21 600 euros par an. Et TimescaleDB c'est gratuit en self-hosted. ROI immédiat."

➡️ Slide suivante — **tu dois être à ~23:30**

## [SLIDE 18 — Points clés] ⏱ ~23:30

*Balayage rapide, pas besoin de tout lire.*

"Pour résumer. À gauche, les avantages : c'est une extension PostgreSQL, pas de migration, pas de nouveau langage à apprendre. Partitionnement automatique, compression native, retention, continuous aggregates. C'est production-ready.

À droite, les pièges : utilisez TIMESTAMPTZ, adaptez la taille de vos chunks, testez la compression avant de la mettre en prod — les UUIDs ça compresse mal, les données répétitives ça compresse très bien. Et planifiez votre stratégie de rétention dès le début."

➡️ Slide suivante — **tu dois être à ~24:30**

## [SLIDE 19 — Ressources] ⏱ ~24:30

"La doc est excellente sur docs.timescale.com. Tout le code de cette présentation est sur GitHub — le repo, les scripts SQL, un Docker Compose prêt à l'emploi. Clonez, faites `make start`, et vous avez un environnement qui tourne en 30 secondes. N'hésitez pas à tester."

➡️ Slide suivante — **tu dois être à ~25:00**

## [SLIDE 20 — Merci !] ⏱ ~25:00 — ✅ CHECKPOINT < 28:00

"Merci ! Des questions ?"

---

## Aide-mémoire : les fusibles

Si tu es en retard, voici quoi couper :

| Retard | Quoi couper |
|--------|------------|
| ~2 min | Retention : montre juste la slide, skip la démo DataGrip |
| ~4 min | + Compression : montre les stats globales, skip le détail par chunk |
| ~6 min | + Caggs : skip le EXPLAIN ANALYZE, montre juste le résultat de la cagg |
| Urgence | Skip les slides REX Karnott détails, passe directement aux gains mesurés |

## Rappels

- [ ] Lancer `prep-02-compression.sql` et `prep-03-caggs.sql` AVANT la prez
- [ ] DataGrip ouvert avec les 4 scripts de démo prêts
- [ ] Vérifier que Docker tourne et que la base répond
- [ ] Mentionner TigerData (rebrand) quand tu parles de TimescaleDB
- [ ] `timescaledb_toolkit` = extension séparée, le dire pendant la démo hyperfunctions
