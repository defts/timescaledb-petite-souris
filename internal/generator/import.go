package generator

import (
	"context"
	"fmt"
	"sync"
	"sync/atomic"
	"time"

	"github.com/jackc/pgx/v5"
)

// Import génère et insère des données en masse avec workers parallèles
func (g *Generator) Import(ctx context.Context, totalRows, batchSize, numWorkers int) error {
	fmt.Printf("📊 Génération de %d lignes avec %d workers (batch=%d)\n", totalRows, numWorkers, batchSize)

	// Compteurs
	var (
		inserted int64
		errors   int64
	)

	// Canal de travail
	jobs := make(chan int, numWorkers*2)

	// WaitGroup pour les workers
	var wg sync.WaitGroup

	// Démarrer les workers
	for w := 1; w <= numWorkers; w++ {
		wg.Add(1)
		go func(workerID int) {
			defer wg.Done()
			g.worker(ctx, workerID, jobs, batchSize, &inserted, &errors)
		}(w)
	}

	// Afficher la progression
	done := make(chan bool)
	go g.printProgress(totalRows, &inserted, &errors, done)

	// Envoyer les jobs
	startTime := time.Now()
	numBatches := (totalRows + batchSize - 1) / batchSize
	remainingRows := totalRows

	for i := 0; i < numBatches; i++ {
		// Calculer la taille de ce batch (peut être plus petit pour le dernier)
		currentBatchSize := batchSize
		if remainingRows < batchSize {
			currentBatchSize = remainingRows
		}
		remainingRows -= currentBatchSize

		select {
		case <-ctx.Done():
			close(jobs)
			wg.Wait()
			return ctx.Err()
		case jobs <- currentBatchSize:
		}
	}

	// Fermer le canal et attendre les workers
	close(jobs)
	wg.Wait()
	done <- true

	// Résumé
	duration := time.Since(startTime)
	fmt.Printf("\n\n✅ Import terminé en %s\n", duration.Round(time.Second))
	fmt.Printf("   Lignes insérées : %d\n", inserted)
	fmt.Printf("   Erreurs         : %d\n", errors)
	fmt.Printf("   Vitesse         : %.0f lignes/sec\n", float64(inserted)/duration.Seconds())

	return nil
}

// worker traite les batches d'insertion
func (g *Generator) worker(ctx context.Context, workerID int, jobs <-chan int, batchSize int, inserted, errors *int64) {
	for batchSize := range jobs {
		if err := g.insertBatch(ctx, batchSize); err != nil {
			atomic.AddInt64(errors, 1)
			fmt.Printf("\n❌ Worker %d erreur: %v\n", workerID, err)
		} else {
			atomic.AddInt64(inserted, int64(batchSize))
		}
	}
}

// insertBatch insère un batch de données
func (g *Generator) insertBatch(ctx context.Context, batchSize int) error {
	// Générer les données
	rows := make([]ToothLoss, batchSize)
	for i := 0; i < batchSize; i++ {
		rows[i] = g.GenerateOne()
	}

	// Préparer le batch insert
	batch := &pgx.Batch{}
	for _, row := range rows {
		batch.Queue(
			"INSERT INTO tooth_loss (collected_at, child_id, tooth_number, country_code, price) VALUES ($1, $2, $3, $4, $5)",
			row.CollectedAt, row.ChildID, row.ToothNumber, row.CountryCode, row.Price,
		)
	}

	// Exécuter le batch
	br := g.pool.SendBatch(ctx, batch)
	defer br.Close()

	// Consommer tous les résultats
	for i := 0; i < batchSize; i++ {
		if _, err := br.Exec(); err != nil {
			return fmt.Errorf("batch insert failed at row %d: %w", i, err)
		}
	}

	return nil
}

// printProgress affiche la progression en temps réel
func (g *Generator) printProgress(total int, inserted, errors *int64, done <-chan bool) {
	ticker := time.NewTicker(2 * time.Second)
	defer ticker.Stop()

	for {
		select {
		case <-done:
			return
		case <-ticker.C:
			ins := atomic.LoadInt64(inserted)
			errs := atomic.LoadInt64(errors)
			pct := float64(ins) / float64(total) * 100
			fmt.Printf("\r⏳ Progression: %d/%d (%.1f%%) | Erreurs: %d", ins, total, pct, errs)
		}
	}
}

// BackfillRealtime génère des données denses pour la dernière heure
// avec un nombre configurable de lignes par seconde
func (g *Generator) BackfillRealtime(ctx context.Context, linesPerSecond, batchSize int) error {
	duration := 1 * time.Hour
	now := time.Now()
	startTime := now.Add(-duration)

	totalSeconds := int(duration.Seconds())
	totalRows := totalSeconds * linesPerSecond

	fmt.Printf("📊 Backfill temps réel: %d lignes (%d lignes/sec sur %d secondes)\n",
		totalRows, linesPerSecond, totalSeconds)

	var inserted int64
	var errors int64

	startExec := time.Now()

	// Générer les données seconde par seconde
	for i := 0; i < totalSeconds; i++ {
		timestamp := startTime.Add(time.Duration(i) * time.Second)

		// Générer les lignes pour cette seconde
		rows := g.GenerateRealtimeDense(linesPerSecond, timestamp)

		// Insérer par batch
		for j := 0; j < len(rows); j += batchSize {
			end := j + batchSize
			if end > len(rows) {
				end = len(rows)
			}

			batch := rows[j:end]
			if err := g.insertBatchRows(ctx, batch); err != nil {
				atomic.AddInt64(&errors, 1)
				fmt.Printf("\n❌ Erreur à %s: %v\n", timestamp, err)
			} else {
				atomic.AddInt64(&inserted, int64(len(batch)))
			}
		}

		// Afficher la progression toutes les 10 secondes
		if (i+1)%10 == 0 {
			pct := float64(i+1) / float64(totalSeconds) * 100
			fmt.Printf("\r⏳ Progression: %d/%d secondes (%.1f%%)", i+1, totalSeconds, pct)
		}

		select {
		case <-ctx.Done():
			return ctx.Err()
		default:
		}
	}

	execDuration := time.Since(startExec)
	fmt.Printf("\n\n✅ Backfill terminé en %s\n", execDuration.Round(time.Second))
	fmt.Printf("   Lignes insérées : %d\n", inserted)
	fmt.Printf("   Erreurs         : %d\n", errors)
	fmt.Printf("   Vitesse         : %.0f lignes/sec\n", float64(inserted)/execDuration.Seconds())
	fmt.Printf("   Période         : %s → %s\n", startTime.Format("15:04:05"), now.Format("15:04:05"))

	return nil
}

// insertBatchRows insère un batch de ToothLoss déjà générés
func (g *Generator) insertBatchRows(ctx context.Context, rows []ToothLoss) error {
	batch := &pgx.Batch{}
	for _, row := range rows {
		batch.Queue(
			"INSERT INTO tooth_loss (collected_at, child_id, tooth_number, country_code, price) VALUES ($1, $2, $3, $4, $5)",
			row.CollectedAt, row.ChildID, row.ToothNumber, row.CountryCode, row.Price,
		)
	}

	br := g.pool.SendBatch(ctx, batch)
	defer br.Close()

	for i := 0; i < len(rows); i++ {
		if _, err := br.Exec(); err != nil {
			return fmt.Errorf("batch insert failed at row %d: %w", i, err)
		}
	}

	return nil
}

// BackfillDelta remplit les données entre la dernière date trackée et maintenant
// avec un nombre de lignes par JOUR légèrement aléatoire (±30%)
func (g *Generator) BackfillDelta(ctx context.Context, avgLinesPerDay, batchSize int) error {
	// Récupérer la dernière date de remplissage
	lastFillDate, err := g.GetLastFillDate(ctx)
	if err != nil {
		return fmt.Errorf("failed to get last fill date: %w", err)
	}

	now := time.Now()

	// Calculer la durée à remplir
	duration := now.Sub(lastFillDate)

	// Si moins d'une minute, rien à faire
	if duration < time.Minute {
		fmt.Println("✅ Aucun delta à remplir (déjà à jour)")
		return nil
	}

	// Calculer le nombre de jours (avec décimales) pour estimer les lignes
	daysToFill := duration.Hours() / 24.0
	estimatedRows := int(daysToFill * float64(avgLinesPerDay))

	fmt.Printf("📊 Backfill delta: ~%d lignes sur %.2f jours (%.1f heures)\n",
		estimatedRows, daysToFill, duration.Hours())
	fmt.Printf("   Moyenne: %d lignes/jour (avec variabilité ±30%%)\n", avgLinesPerDay)
	fmt.Printf("   Période: %s → %s\n", lastFillDate.Format("2006-01-02 15:04:05"), now.Format("2006-01-02 15:04:05"))
	fmt.Println()

	var inserted int64
	var errors int64

	startExec := time.Now()
	lastProgressUpdate := time.Now()

	// Générer les données sur toute la période
	totalSeconds := int(duration.Seconds())
	linesToGenerate := estimatedRows

	// Générer par batches
	var batchRows []ToothLoss
	for i := 0; i < linesToGenerate; i++ {
		// Timestamp aléatoire dans la période
		secondOffset := g.rng.Intn(totalSeconds)
		timestamp := lastFillDate.Add(time.Duration(secondOffset) * time.Second)

		// Générer une ligne
		row := g.generateWithTimestamp(timestamp)
		batchRows = append(batchRows, row)

		// Insérer quand le batch est plein ou à la fin
		if len(batchRows) >= batchSize || i == linesToGenerate-1 {
			if err := g.insertBatchRows(ctx, batchRows); err != nil {
				atomic.AddInt64(&errors, 1)
				fmt.Printf("\n❌ Erreur: %v\n", err)
			} else {
				atomic.AddInt64(&inserted, int64(len(batchRows)))
			}
			batchRows = nil
		}

		// Afficher la progression toutes les 2 secondes
		if time.Since(lastProgressUpdate) >= 2*time.Second {
			pct := float64(i+1) / float64(linesToGenerate) * 100
			elapsed := time.Since(startExec)
			ins := atomic.LoadInt64(&inserted)
			rate := float64(ins) / elapsed.Seconds()

			var remaining time.Duration
			if i > 0 {
				avgTimePerRow := elapsed / time.Duration(i+1)
				remaining = avgTimePerRow * time.Duration(linesToGenerate-i-1)
			}

			fmt.Printf("\r⏳ Progression: %.1f%% | %d/%d lignes | %.0f lignes/sec | Restant: ~%s",
				pct, ins, linesToGenerate, rate, remaining.Round(time.Second))
			lastProgressUpdate = time.Now()
		}

		select {
		case <-ctx.Done():
			return ctx.Err()
		default:
		}
	}

	execDuration := time.Since(startExec)
	ins := atomic.LoadInt64(&inserted)
	fmt.Printf("\n\n✅ Backfill delta terminé en %s\n", execDuration.Round(time.Second))
	fmt.Printf("   Lignes insérées : %d\n", ins)
	fmt.Printf("   Erreurs         : %d\n", atomic.LoadInt64(&errors))
	fmt.Printf("   Vitesse moyenne : %.0f lignes/sec\n", float64(ins)/execDuration.Seconds())
	fmt.Printf("   Période         : %s → %s\n",
		lastFillDate.Format("2006-01-02 15:04:05"),
		now.Format("2006-01-02 15:04:05"))

	// Mettre à jour la dernière date de remplissage
	if err := g.UpdateLastFillDate(ctx, now); err != nil {
		return fmt.Errorf("backfill succeeded but failed to update state: %w", err)
	}

	fmt.Println("   État mis à jour ✅")

	return nil
}

// BackfillHistoricalDays génère des données uniformes sur un nombre de jours donné
// avec un nombre de lignes par JOUR légèrement aléatoire (±30%)
func (g *Generator) BackfillHistoricalDays(ctx context.Context, avgLinesPerDay, batchSize int, totalDays int) error {
	// Récupérer la dernière date de remplissage comme point de départ
	lastFillDate, err := g.GetLastFillDate(ctx)
	if err != nil {
		return fmt.Errorf("failed to get last fill date: %w", err)
	}

	startTime := lastFillDate
	now := startTime.Add(time.Duration(totalDays) * 24 * time.Hour)

	estimatedRows := totalDays * avgLinesPerDay
	years := float64(totalDays) / 365.0

	if years >= 1.0 {
		fmt.Printf("📊 Backfill historique: ~%d lignes sur %.1f ans (%d jours)\n", estimatedRows, years, totalDays)
	} else {
		fmt.Printf("📊 Backfill historique: ~%d lignes sur %d jours\n", estimatedRows, totalDays)
	}
	fmt.Printf("   Moyenne: %d lignes/jour (avec variabilité ±30%%)\n", avgLinesPerDay)
	fmt.Printf("   Période: %s → %s\n", startTime.Format("2006-01-02"), now.Format("2006-01-02"))
	fmt.Println()

	var inserted int64
	var errors int64

	startExec := time.Now()
	lastProgressUpdate := time.Now()

	// Générer les données jour par jour
	for day := 0; day < totalDays; day++ {
		dayStart := startTime.Add(time.Duration(day) * 24 * time.Hour)

		// Nombre de lignes aléatoire autour de avgLinesPerDay (±30%)
		// Ex: si avg=1000, générer entre 700 et 1300 lignes
		variance := int(float64(avgLinesPerDay) * 0.3)
		linesToday := avgLinesPerDay - variance + g.rng.Intn(2*variance+1)
		if linesToday < 1 {
			linesToday = 1
		}

		// Répartir les lignes uniformément sur la journée (86400 secondes)
		secondsInDay := 86400
		var batchRows []ToothLoss

		for i := 0; i < linesToday; i++ {
			// Timestamp aléatoire dans la journée
			secondOffset := g.rng.Intn(secondsInDay)
			timestamp := dayStart.Add(time.Duration(secondOffset) * time.Second)

			// Générer une ligne
			row := g.generateWithTimestamp(timestamp)
			batchRows = append(batchRows, row)

			// Insérer quand le batch est plein ou à la fin
			if len(batchRows) >= batchSize || i == linesToday-1 {
				if err := g.insertBatchRows(ctx, batchRows); err != nil {
					atomic.AddInt64(&errors, 1)
					fmt.Printf("\n❌ Erreur à %s: %v\n", timestamp.Format("2006-01-02"), err)
				} else {
					atomic.AddInt64(&inserted, int64(len(batchRows)))
				}
				batchRows = nil
			}
		}

		// Afficher la progression toutes les 2 secondes
		if time.Since(lastProgressUpdate) >= 2*time.Second {
			pct := float64(day+1) / float64(totalDays) * 100
			elapsed := time.Since(startExec)
			ins := atomic.LoadInt64(&inserted)
			rate := float64(ins) / elapsed.Seconds()

			var remaining time.Duration
			if day > 0 {
				avgTimePerDay := elapsed / time.Duration(day+1)
				remaining = avgTimePerDay * time.Duration(totalDays-day-1)
			}

			fmt.Printf("\r⏳ Progression: %.1f%% | Jour %d/%d | %d lignes | %.0f lignes/sec | Restant: ~%s",
				pct, day+1, totalDays, ins, rate, remaining.Round(time.Second))
			lastProgressUpdate = time.Now()
		}

		select {
		case <-ctx.Done():
			return ctx.Err()
		default:
		}
	}

	execDuration := time.Since(startExec)
	ins := atomic.LoadInt64(&inserted)
	fmt.Printf("\n\n✅ Backfill terminé en %s\n", execDuration.Round(time.Second))
	fmt.Printf("   Lignes insérées : %d\n", ins)
	fmt.Printf("   Erreurs         : %d\n", atomic.LoadInt64(&errors))
	fmt.Printf("   Vitesse moyenne : %.0f lignes/sec\n", float64(ins)/execDuration.Seconds())
	fmt.Printf("   Période         : %s → %s\n",
		startTime.Format("2006-01-02"),
		now.Format("2006-01-02"))

	// Mettre à jour la dernière date de remplissage
	if err := g.UpdateLastFillDate(ctx, now); err != nil {
		return fmt.Errorf("backfill succeeded but failed to update state: %w", err)
	}

	fmt.Println("   État mis à jour ✅")

	return nil
}
