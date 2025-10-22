package generator

import (
	"context"
	"fmt"
	"math/rand"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
)

// Generator génère des données aléatoires pour tooth_loss
type Generator struct {
	pool         *pgxpool.Pool
	countries    []string
	maxChildID   int64
	startDate    time.Time
	endDate      time.Time
	rng          *rand.Rand
}

// ToothLoss représente une ligne de la table tooth_loss
type ToothLoss struct {
	CollectedAt  time.Time
	ChildID      int64
	ToothNumber  int
	CountryCode  string
	Price        float64
}

// Config contient la configuration du générateur
type Config struct {
	DatabaseURL  string
	MaxChildID   int64     // Nombre max d'enfants (ex: 50000000)
	StartDate    time.Time // Début de la période (ex: il y a 5 ans)
	EndDate      time.Time // Fin de la période (ex: maintenant)
}

// NewGenerator crée un nouveau générateur
func NewGenerator(ctx context.Context, cfg Config) (*Generator, error) {
	// Connexion à PostgreSQL
	pool, err := pgxpool.New(ctx, cfg.DatabaseURL)
	if err != nil {
		return nil, fmt.Errorf("failed to connect to database: %w", err)
	}

	// Tester la connexion
	if err := pool.Ping(ctx); err != nil {
		return nil, fmt.Errorf("failed to ping database: %w", err)
	}

	// Charger les codes pays depuis la DB
	countries, err := loadCountries(ctx, pool)
	if err != nil {
		return nil, fmt.Errorf("failed to load countries: %w", err)
	}

	// Déterminer le nombre d'enfants dans la DB
	maxChildID := cfg.MaxChildID
	if maxChildID == 0 {
		maxChildID, err = getMaxChildID(ctx, pool)
		if err != nil {
			return nil, fmt.Errorf("failed to get max child_id: %w", err)
		}
	}

	fmt.Printf("ℹ️  Configuration: %d pays, %d enfants max\n", len(countries), maxChildID)

	return &Generator{
		pool:       pool,
		countries:  countries,
		maxChildID: maxChildID,
		startDate:  cfg.StartDate,
		endDate:    cfg.EndDate,
		rng:        rand.New(rand.NewSource(time.Now().UnixNano())),
	}, nil
}

// Close ferme la connexion à la base de données
func (g *Generator) Close() {
	g.pool.Close()
}

// loadCountries charge tous les codes pays depuis la DB
func loadCountries(ctx context.Context, pool *pgxpool.Pool) ([]string, error) {
	rows, err := pool.Query(ctx, "SELECT code FROM countries ORDER BY code")
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var countries []string
	for rows.Next() {
		var code string
		if err := rows.Scan(&code); err != nil {
			return nil, err
		}
		countries = append(countries, code)
	}

	return countries, rows.Err()
}

// getMaxChildID retourne le child_id maximum dans la table children
func getMaxChildID(ctx context.Context, pool *pgxpool.Pool) (int64, error) {
	var maxID int64
	err := pool.QueryRow(ctx, "SELECT MAX(child_id) FROM children").Scan(&maxID)
	if err != nil {
		return 0, err
	}
	return maxID, nil
}

// Prix courants donnés par les parents (en euros)
var commonPrices = []float64{0.20, 0.50, 1.00, 2.00, 5.00, 10.00, 20.00}

// GenerateOne génère une ligne aléatoire
func (g *Generator) GenerateOne() ToothLoss {
	// Timestamp aléatoire entre startDate et endDate
	delta := g.endDate.Sub(g.startDate)
	randomDuration := time.Duration(g.rng.Int63n(int64(delta)))
	timestamp := g.startDate.Add(randomDuration)

	// Child ID aléatoire entre 1 et maxChildID
	childID := g.rng.Int63n(g.maxChildID) + 1

	// Tooth number entre 1 et 20
	toothNumber := g.rng.Intn(20) + 1

	// Country aléatoire
	countryCode := g.countries[g.rng.Intn(len(g.countries))]

	// Prix réaliste choisi parmi les valeurs courantes
	// Avec une distribution favorisant les petites sommes
	var price float64
	r := g.rng.Float64()
	if r < 0.15 {
		price = 0.20 // 15%
	} else if r < 0.35 {
		price = 0.50 // 20%
	} else if r < 0.60 {
		price = 1.00 // 25%
	} else if r < 0.80 {
		price = 2.00 // 20%
	} else if r < 0.92 {
		price = 5.00 // 12%
	} else if r < 0.98 {
		price = 10.00 // 6%
	} else {
		price = 20.00 // 2% (les généreux)
	}

	return ToothLoss{
		CollectedAt: timestamp,
		ChildID:     childID,
		ToothNumber: toothNumber,
		CountryCode: countryCode,
		Price:       price,
	}
}

// GenerateRealtime génère une ligne avec un timestamp actuel (temps réel)
// Utilisé pour le mode stream pour démontrer les continuous aggregates
func (g *Generator) GenerateRealtime() ToothLoss {
	return g.generateWithTimestamp(time.Now())
}

// GenerateRealtimeDense génère plusieurs lignes pour un timestamp donné
// Utilisé pour générer des données denses pour la démo
func (g *Generator) GenerateRealtimeDense(count int, timestamp time.Time) []ToothLoss {
	results := make([]ToothLoss, count)
	for i := 0; i < count; i++ {
		results[i] = g.generateWithTimestamp(timestamp)
	}
	return results
}

// generateWithTimestamp génère une ligne avec le timestamp spécifié
func (g *Generator) generateWithTimestamp(timestamp time.Time) ToothLoss {
	// Child ID aléatoire entre 1 et maxChildID
	childID := g.rng.Int63n(g.maxChildID) + 1

	// Tooth number entre 1 et 20
	toothNumber := g.rng.Intn(20) + 1

	// Country aléatoire
	countryCode := g.countries[g.rng.Intn(len(g.countries))]

	// Prix réaliste choisi parmi les valeurs courantes
	// Avec une distribution favorisant les petites sommes
	var price float64
	r := g.rng.Float64()
	if r < 0.15 {
		price = 0.20 // 15%
	} else if r < 0.35 {
		price = 0.50 // 20%
	} else if r < 0.60 {
		price = 1.00 // 25%
	} else if r < 0.80 {
		price = 2.00 // 20%
	} else if r < 0.92 {
		price = 5.00 // 12%
	} else if r < 0.98 {
		price = 10.00 // 6%
	} else {
		price = 20.00 // 2% (les généreux)
	}

	return ToothLoss{
		CollectedAt: timestamp,
		ChildID:     childID,
		ToothNumber: toothNumber,
		CountryCode: countryCode,
		Price:       price,
	}
}
