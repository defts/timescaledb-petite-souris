package generator

import (
	"context"
	"fmt"
	"time"
)

// GetLastFillDate récupère la dernière date jusqu'à laquelle les données ont été remplies
func (g *Generator) GetLastFillDate(ctx context.Context) (time.Time, error) {
	var lastFillDate time.Time
	err := g.pool.QueryRow(ctx, "SELECT last_fill_date FROM data_generation_state WHERE id = 1").Scan(&lastFillDate)
	if err != nil {
		return time.Time{}, fmt.Errorf("failed to get last fill date: %w", err)
	}
	return lastFillDate, nil
}

// UpdateLastFillDate met à jour la dernière date de remplissage
func (g *Generator) UpdateLastFillDate(ctx context.Context, newDate time.Time) error {
	_, err := g.pool.Exec(ctx,
		"UPDATE data_generation_state SET last_fill_date = $1, updated_at = NOW() WHERE id = 1",
		newDate,
	)
	if err != nil {
		return fmt.Errorf("failed to update last fill date: %w", err)
	}
	return nil
}

// SetLastFillDate initialise ou force la dernière date de remplissage
// Utile pour réinitialiser l'état ou commencer à une date spécifique
func (g *Generator) SetLastFillDate(ctx context.Context, date time.Time) error {
	_, err := g.pool.Exec(ctx,
		`INSERT INTO data_generation_state (id, last_fill_date, updated_at)
		 VALUES (1, $1, NOW())
		 ON CONFLICT (id) DO UPDATE SET last_fill_date = $1, updated_at = NOW()`,
		date,
	)
	if err != nil {
		return fmt.Errorf("failed to set last fill date: %w", err)
	}
	return nil
}
