package generator

import (
	"context"
	"fmt"
	"sync/atomic"
	"time"
)

// Stream insère des données en continu à un taux donné (lignes/sec)
func (g *Generator) Stream(ctx context.Context, rate int) error {
	fmt.Printf("📡 Mode stream: %d lignes/seconde\n", rate)
	fmt.Printf("   Appuyez sur Ctrl+C pour arrêter\n\n")

	var inserted int64
	var errors int64

	// Ticker pour contrôler le taux d'insertion
	interval := time.Second / time.Duration(rate)
	ticker := time.NewTicker(interval)
	defer ticker.Stop()

	// Afficher les stats toutes les 5 secondes
	statsTicker := time.NewTicker(5 * time.Second)
	defer statsTicker.Stop()

	startTime := time.Now()

	for {
		select {
		case <-ctx.Done():
			g.printStreamStats(startTime, inserted, errors)
			return ctx.Err()

		case <-ticker.C:
			// Générer et insérer une ligne avec timestamp actuel (temps réel)
			row := g.GenerateRealtime()
			if err := g.insertOne(ctx, row); err != nil {
				atomic.AddInt64(&errors, 1)
				fmt.Printf("❌ Erreur: %v\n", err)
			} else {
				atomic.AddInt64(&inserted, 1)
			}

		case <-statsTicker.C:
			g.printStreamStats(startTime, inserted, errors)
		}
	}
}

// insertOne insère une seule ligne
func (g *Generator) insertOne(ctx context.Context, row ToothLoss) error {
	_, err := g.pool.Exec(ctx,
		"INSERT INTO tooth_loss (collected_at, child_id, tooth_number, country_code, price) VALUES ($1, $2, $3, $4, $5)",
		row.CollectedAt, row.ChildID, row.ToothNumber, row.CountryCode, row.Price,
	)
	return err
}

// printStreamStats affiche les statistiques du stream
func (g *Generator) printStreamStats(startTime time.Time, inserted, errors int64) {
	duration := time.Since(startTime)
	ins := atomic.LoadInt64(&inserted)
	errs := atomic.LoadInt64(&errors)
	rate := float64(ins) / duration.Seconds()

	fmt.Printf("📊 Stats: %d lignes insérées | %d erreurs | %.1f lignes/sec | Durée: %s\n",
		ins, errs, rate, duration.Round(time.Second))
}
