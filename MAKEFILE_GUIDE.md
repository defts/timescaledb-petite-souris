# Guide du Makefile 📋

Le Makefile simplifie toutes les opérations pour la démo TimescaleDB. Plus besoin de taper les longues commandes `psql` !

## 🚀 Démarrage rapide

### Pour commencer de zéro

```bash
make demo
```

Cette commande unique fait tout :
1. ✅ Démarre Docker avec TimescaleDB
2. ✅ Exécute le script 01 (setup)
3. ✅ Exécute le script 02 (génération de ~100M lignes)
4. ✅ Prêt pour les démos live !

⏱️ **Temps total : ~3-5 minutes**

---

## 📚 Toutes les commandes disponibles

### Gestion Docker

| Commande | Description |
|----------|-------------|
| `make start` | Démarre TimescaleDB et attend qu'il soit prêt |
| `make stop` | Arrête la stack Docker |
| `make restart` | Redémarre proprement |
| `make reset` | ⚠️ TOUT supprimer (avec confirmation) |
| `make logs` | Voir les logs en temps réel |
| `make status` | Statut des containers |

### Scripts SQL (démos)

| Commande | Script | Description | Durée |
|----------|--------|-------------|-------|
| `make 01` | 01-setup.sql | Setup initial (extension + hypertable) | ~5s |
| `make 02` | 02-generate-data.sql | Génération de ~100M lignes | ~2-3min |
| `make 03` | 03-queries.sql | Requêtes temporelles (time_bucket) | ~30s |
| `make 04` | 04-compression.sql | Compression des données | ~1-2min |
| `make 05` | 05-retention.sql | Retention policies | ~10s |
| `make 06` | 06-continuous-aggregates.sql | Continuous aggregates | ~30s |
| `make all` | Tous les scripts | Exécute 01 à 06 séquentiellement | ~5-7min |

### Utilitaires

| Commande | Description |
|----------|-------------|
| `make psql` | Se connecter directement à psql |
| `make stats` | Afficher les statistiques de la base |
| `make clean-db` | Supprimer la table tooth_loss (sans tout détruire) |
| `make check` | Vérifier que l'environnement est OK |
| `make help` | Afficher toutes les commandes |

### Présentation Slidev

| Commande | Description |
|----------|-------------|
| `make slides` | Lancer Slidev en mode dev |
| `make slides-build` | Build pour production |
| `make slides-export` | Exporter en PDF |

---

## 🎯 Workflows typiques

### Workflow 1 : Première utilisation

```bash
# Cloner le repo
git clone https://github.com/defts/timescaledb-petite-souris
cd timescaledb-petite-souris

# Vérifier que tout est installé
make check

# Setup complet
make demo

# Lancer les slides
make slides
```

### Workflow 2 : Préparer la présentation

```bash
# Démarrer la stack
make start

# Setup rapide
make 01
make 02

# Vérifier les données
make stats

# Lancer les slides
make slides
```

### Workflow 3 : Réinitialiser complètement

```bash
# Tout supprimer
make reset

# Recommencer de zéro
make demo
```

### Workflow 4 : Tests rapides

```bash
# Pour tester avec moins de données (plus rapide)
make start
make 01
make quick-demo  # ~10M lignes au lieu de 100M
```

### Workflow 5 : Pendant la présentation

```bash
# Terminal 1 : Slides
make slides

# Terminal 2 : Démos SQL
make 03    # Requêtes temporelles
make 04    # Compression
make 05    # Retention
make 06    # Continuous aggregates

# Si besoin de vérifier quelque chose
make stats
make psql
```

---

## 💡 Astuces

### Voir les commandes exécutées

Le Makefile affiche des messages colorés pour chaque étape. Si vous voulez voir les commandes SQL exactes, regardez les fichiers dans `scripts/`.

### Exécuter plusieurs scripts d'affilée

```bash
make 01 && make 02 && make 03
# ou
make all
```

### Connexion psql manuelle

```bash
make psql
# Équivalent à :
# PGPASSWORD=password psql -h localhost -U postgres -d postgres
```

### Vérifier rapidement la base

```bash
# Nombre de lignes et taille
make stats

# Détails complets
make psql
\d tooth_loss
SELECT COUNT(*) FROM tooth_loss;
\q
```

---

## 🐛 Troubleshooting

### TimescaleDB ne démarre pas

```bash
make logs
# Si problème, redémarrer :
make restart
```

### La base semble vide

```bash
make stats
# Si 0 lignes, refaire le setup :
make 01
make 02
```

### Erreur "table already exists"

```bash
# Nettoyer la table
make clean-db
# Refaire le setup
make 01
```

### Tout casser et recommencer

```bash
make reset
make demo
```

---

## 📊 Commandes de monitoring

### Pendant la génération de données

```bash
# Terminal 1
make 02

# Terminal 2 (dans un autre terminal)
watch -n 2 'make stats'
```

### Voir les chunks créés

```bash
make psql
SELECT * FROM timescaledb_information.chunks WHERE hypertable_name = 'tooth_loss';
\q
```

### Voir les jobs TimescaleDB

```bash
make psql
SELECT * FROM timescaledb_information.jobs;
\q
```

---

## 🎬 Pour le jour J

### Checklist avant la présentation

```bash
# 1. Vérifier l'environnement
make check

# 2. Tout préparer
make demo

# 3. Vérifier que ça marche
make stats
make psql
\d tooth_loss
SELECT COUNT(*) FROM tooth_loss;
\q

# 4. Tester une requête rapide
make psql
SELECT time_bucket('1 day', time) AS day, COUNT(*) FROM tooth_loss GROUP BY day ORDER BY day DESC LIMIT 10;
\q

# 5. Lancer les slides
make slides
```

### Avoir un terminal propre pendant la démo

```bash
# Ouvrir plusieurs terminaux/onglets :

# Terminal 1 : Slides
make slides

# Terminal 2 : Démos SQL (garder ouvert)
make psql

# Terminal 3 : Monitoring (optionnel)
watch -n 5 'make stats'
```

---

## 🔧 Personnalisation

### Modifier les paramètres de connexion

Éditer le `Makefile` et changer les variables en haut :

```makefile
DB_HOST = localhost
DB_PORT = 5432
DB_USER = postgres
DB_NAME = postgres
DB_PASSWORD = password
```

### Ajouter vos propres commandes

Ajouter dans le `Makefile` :

```makefile
.PHONY: mon-script
mon-script: ## Ma description
	@echo "🚀 Mon script personnalisé"
	@$(PSQL_FILE) scripts/mon-script.sql
```

Puis utiliser avec :

```bash
make mon-script
```

---

## 🎉 C'est tout !

Le Makefile rend la démo beaucoup plus fluide. Plus besoin de se souvenir des commandes `psql` compliquées !

**Commande la plus importante :**

```bash
make help
```

Bon meetup ! 🦷✨
