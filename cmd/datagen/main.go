package main

import (
	"context"
	"flag"
	"fmt"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/defts/timescaledb-petite-souris/internal/generator"
)

const (
	defaultDBURL    = "postgres://postgres:password@localhost:5432/petite_souris?sslmode=disable"
	defaultMaxChild = 50000000 // 50M enfants
)

func main() {
	if len(os.Args) < 2 {
		printUsage()
		os.Exit(1)
	}

	// Sous-commandes
	importCmd := flag.NewFlagSet("import", flag.ExitOnError)
	streamCmd := flag.NewFlagSet("stream", flag.ExitOnError)
	backfillCmd := flag.NewFlagSet("backfill", flag.ExitOnError)
	backfillHistoricalCmd := flag.NewFlagSet("backfill-historical", flag.ExitOnError)
	backfillDeltaCmd := flag.NewFlagSet("backfill-delta", flag.ExitOnError)
	setStateCmd := flag.NewFlagSet("set-state", flag.ExitOnError)

	// Flags communs
	importDB := importCmd.String("db", defaultDBURL, "Database URL")
	streamDB := streamCmd.String("db", defaultDBURL, "Database URL")
	backfillDB := backfillCmd.String("db", defaultDBURL, "Database URL")
	backfillHistoricalDB := backfillHistoricalCmd.String("db", defaultDBURL, "Database URL")
	backfillDeltaDB := backfillDeltaCmd.String("db", defaultDBURL, "Database URL")
	setStateDB := setStateCmd.String("db", defaultDBURL, "Database URL")

	// Flags pour import
	importRows := importCmd.Int("rows", 1000000, "Nombre de lignes à générer")
	importBatch := importCmd.Int("batch", 10000, "Taille des batchs")
	importWorkers := importCmd.Int("workers", 4, "Nombre de workers parallèles")

	// Flags pour stream
	streamRate := streamCmd.Int("rate", 100, "Lignes par seconde")

	// Flags pour backfill
	backfillRate := backfillCmd.Int("rate", 10, "Lignes par seconde")
	backfillBatch := backfillCmd.Int("batch", 100, "Taille des batchs")

	// Flags pour backfill-historical
	backfillHistoricalRate := backfillHistoricalCmd.Int("rate", 1000, "Lignes par jour (moyenne)")
	backfillHistoricalBatch := backfillHistoricalCmd.Int("batch", 100, "Taille des batchs")
	backfillHistoricalYears := backfillHistoricalCmd.Int("years", 0, "Nombre d'années à générer")
	backfillHistoricalDays := backfillHistoricalCmd.Int("days", 0, "Nombre de jours à générer (prioritaire sur --years)")

	// Flags pour backfill-delta
	backfillDeltaRate := backfillDeltaCmd.Int("rate", 1000, "Lignes par jour (moyenne)")
	backfillDeltaBatch := backfillDeltaCmd.Int("batch", 100, "Taille des batchs")

	// Flags pour set-state
	setStateDate := setStateCmd.String("date", "", "Date à définir (format: 2006-01-02 ou 2006-01-02T15:04:05)")

	// Parser la sous-commande
	switch os.Args[1] {
	case "import":
		importCmd.Parse(os.Args[2:])
		if err := runImport(*importDB, *importRows, *importBatch, *importWorkers); err != nil {
			fmt.Fprintf(os.Stderr, "❌ Erreur: %v\n", err)
			os.Exit(1)
		}
	case "stream":
		streamCmd.Parse(os.Args[2:])
		if err := runStream(*streamDB, *streamRate); err != nil {
			fmt.Fprintf(os.Stderr, "❌ Erreur: %v\n", err)
			os.Exit(1)
		}
	case "backfill":
		backfillCmd.Parse(os.Args[2:])
		if err := runBackfill(*backfillDB, *backfillRate, *backfillBatch); err != nil {
			fmt.Fprintf(os.Stderr, "❌ Erreur: %v\n", err)
			os.Exit(1)
		}
	case "backfill-historical":
		backfillHistoricalCmd.Parse(os.Args[2:])
		if err := runBackfillHistorical(*backfillHistoricalDB, *backfillHistoricalRate, *backfillHistoricalBatch, *backfillHistoricalYears, *backfillHistoricalDays); err != nil {
			fmt.Fprintf(os.Stderr, "❌ Erreur: %v\n", err)
			os.Exit(1)
		}
	case "backfill-delta":
		backfillDeltaCmd.Parse(os.Args[2:])
		if err := runBackfillDelta(*backfillDeltaDB, *backfillDeltaRate, *backfillDeltaBatch); err != nil {
			fmt.Fprintf(os.Stderr, "❌ Erreur: %v\n", err)
			os.Exit(1)
		}
	case "set-state":
		setStateCmd.Parse(os.Args[2:])
		if err := runSetState(*setStateDB, *setStateDate); err != nil {
			fmt.Fprintf(os.Stderr, "❌ Erreur: %v\n", err)
			os.Exit(1)
		}
	default:
		printUsage()
		os.Exit(1)
	}
}

func printUsage() {
	fmt.Println("Usage: datagen <command> [options]")
	fmt.Println()
	fmt.Println("Commands:")
	fmt.Println("  import              Import massif de données")
	fmt.Println("  stream              Stream continu de données")
	fmt.Println("  backfill            Remplit la dernière heure avec des données denses")
	fmt.Println("  backfill-historical Remplit plusieurs années avec des données uniformes")
	fmt.Println("  backfill-delta      Remplit le delta depuis la dernière date trackée")
	fmt.Println("  set-state           Définit la dernière date de remplissage (pour initialiser)")
	fmt.Println()
	fmt.Println("Import options:")
	fmt.Println("  --rows      Nombre de lignes à générer (default: 1000000)")
	fmt.Println("  --batch     Taille des batchs (default: 10000)")
	fmt.Println("  --workers   Nombre de workers parallèles (default: 4)")
	fmt.Println()
	fmt.Println("Stream options:")
	fmt.Println("  --rate      Lignes par seconde (default: 100)")
	fmt.Println()
	fmt.Println("Backfill options:")
	fmt.Println("  --rate      Lignes par seconde (default: 10)")
	fmt.Println("  --batch     Taille des batchs (default: 100)")
	fmt.Println()
	fmt.Println("Backfill-historical options:")
	fmt.Println("  --rate      Lignes par jour moyenne (default: 1000)")
	fmt.Println("  --batch     Taille des batchs (default: 100)")
	fmt.Println("  --years     Nombre d'années à générer (default: 5)")
	fmt.Println("  --days      Nombre de jours à générer (prioritaire sur --years)")
	fmt.Println()
	fmt.Println("Backfill-delta options:")
	fmt.Println("  --rate      Lignes par jour moyenne (default: 1000)")
	fmt.Println("  --batch     Taille des batchs (default: 100)")
	fmt.Println()
	fmt.Println("Set-state options:")
	fmt.Println("  --date      Date à définir (format: 2006-01-02 ou 2006-01-02T15:04:05)")
	fmt.Println()
	fmt.Println("Examples:")
	fmt.Println("  # Import massif initial")
	fmt.Println("  datagen import --rows 200000000 --workers 8")
	fmt.Println()
	fmt.Println("  # Remplir plusieurs années de données historiques")
	fmt.Println("  datagen backfill-historical --years 5 --rate 1000")
	fmt.Println()
	fmt.Println("  # Remplir 30 jours de données")
	fmt.Println("  datagen backfill-historical --days 30 --rate 5000")
	fmt.Println()
	fmt.Println("  # Définir la date de départ (ex: 04 novembre 2024)")
	fmt.Println("  datagen set-state --date 2024-11-04")
	fmt.Println()
	fmt.Println("  # Remplir le delta depuis la dernière date")
	fmt.Println("  datagen backfill-delta --rate 1000")
	fmt.Println()
	fmt.Println("  # Stream continu pour démo continuous aggregates")
	fmt.Println("  datagen stream --rate 100")
}

func runImport(dbURL string, rows, batchSize, workers int) error {
	ctx := context.Background()

	// Créer le générateur
	gen, err := generator.NewGenerator(ctx, generator.Config{
		DatabaseURL: dbURL,
		MaxChildID:  0,                                         // 0 = auto-detect depuis la DB
		StartDate:   time.Now().Add(-5 * 365 * 24 * time.Hour), // Il y a 5 ans
		EndDate:     time.Now(),
	})
	if err != nil {
		return fmt.Errorf("failed to create generator: %w", err)
	}
	defer gen.Close()

	// Lancer l'import
	return gen.Import(ctx, rows, batchSize, workers)
}

func runStream(dbURL string, rate int) error {
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	// Gérer Ctrl+C
	sigChan := make(chan os.Signal, 1)
	signal.Notify(sigChan, os.Interrupt, syscall.SIGTERM)
	go func() {
		<-sigChan
		fmt.Println("\n\n⏹️  Arrêt du stream...")
		cancel()
	}()

	// Créer le générateur
	gen, err := generator.NewGenerator(ctx, generator.Config{
		DatabaseURL: dbURL,
		MaxChildID:  0,                                         // 0 = auto-detect depuis la DB
		StartDate:   time.Now().Add(-5 * 365 * 24 * time.Hour), // Il y a 5 ans
		EndDate:     time.Now(),
	})
	if err != nil {
		return fmt.Errorf("failed to create generator: %w", err)
	}
	defer gen.Close()

	// Lancer le stream
	return gen.Stream(ctx, rate)
}

func runBackfill(dbURL string, rate, batchSize int) error {
	ctx := context.Background()

	// Créer le générateur
	gen, err := generator.NewGenerator(ctx, generator.Config{
		DatabaseURL: dbURL,
		MaxChildID:  0,                                         // 0 = auto-detect depuis la DB
		StartDate:   time.Now().Add(-5 * 365 * 24 * time.Hour), // Il y a 5 ans
		EndDate:     time.Now(),
	})
	if err != nil {
		return fmt.Errorf("failed to create generator: %w", err)
	}
	defer gen.Close()

	// Lancer le backfill
	return gen.BackfillRealtime(ctx, rate, batchSize)
}

func runBackfillHistorical(dbURL string, rate, batchSize, years, days int) error {
	ctx := context.Background()

	// Déterminer le nombre de jours à générer
	totalDays := days
	if days == 0 {
		if years == 0 {
			years = 5 // Default
		}
		totalDays = years * 365
	}

	// Créer le générateur
	gen, err := generator.NewGenerator(ctx, generator.Config{
		DatabaseURL: dbURL,
		MaxChildID:  0,                                         // 0 = auto-detect depuis la DB
		StartDate:   time.Now().Add(-5 * 365 * 24 * time.Hour), // Il y a 5 ans
		EndDate:     time.Now(),
	})
	if err != nil {
		return fmt.Errorf("failed to create generator: %w", err)
	}
	defer gen.Close()

	// Lancer le backfill historique avec le nombre de jours
	return gen.BackfillHistoricalDays(ctx, rate, batchSize, totalDays)
}

func runBackfillDelta(dbURL string, rate, batchSize int) error {
	ctx := context.Background()

	// Créer le générateur
	gen, err := generator.NewGenerator(ctx, generator.Config{
		DatabaseURL: dbURL,
		MaxChildID:  0,                                         // 0 = auto-detect depuis la DB
		StartDate:   time.Now().Add(-5 * 365 * 24 * time.Hour), // Il y a 5 ans
		EndDate:     time.Now(),
	})
	if err != nil {
		return fmt.Errorf("failed to create generator: %w", err)
	}
	defer gen.Close()

	// Lancer le backfill delta
	return gen.BackfillDelta(ctx, rate, batchSize)
}

func runSetState(dbURL string, dateStr string) error {
	ctx := context.Background()

	// Créer le générateur
	gen, err := generator.NewGenerator(ctx, generator.Config{
		DatabaseURL: dbURL,
		MaxChildID:  0,                                         // 0 = auto-detect depuis la DB
		StartDate:   time.Now().Add(-5 * 365 * 24 * time.Hour), // Il y a 5 ans
		EndDate:     time.Now(),
	})
	if err != nil {
		return fmt.Errorf("failed to create generator: %w", err)
	}
	defer gen.Close()

	// Parser la date
	var date time.Time
	if dateStr == "" {
		return fmt.Errorf("date is required (use --date)")
	}

	// Essayer différents formats
	formats := []string{
		"2006-01-02",
		"2006-01-02T15:04:05",
		time.RFC3339,
	}

	var parseErr error
	for _, format := range formats {
		date, parseErr = time.Parse(format, dateStr)
		if parseErr == nil {
			break
		}
	}

	if parseErr != nil {
		return fmt.Errorf("invalid date format: %s (expected: 2006-01-02 or 2006-01-02T15:04:05)", dateStr)
	}

	// Récupérer l'ancienne date
	oldDate, err := gen.GetLastFillDate(ctx)
	if err != nil {
		fmt.Printf("⚠️  Impossible de récupérer l'ancienne date: %v\n", err)
	} else {
		fmt.Printf("📊 Ancienne date: %s\n", oldDate.Format("2006-01-02 15:04:05"))
	}

	// Définir la nouvelle date
	if err := gen.SetLastFillDate(ctx, date); err != nil {
		return fmt.Errorf("failed to set state: %w", err)
	}

	fmt.Printf("✅ Nouvelle date définie: %s\n", date.Format("2006-01-02 15:04:05"))
	fmt.Println()
	fmt.Println("💡 Vous pouvez maintenant utiliser 'datagen backfill-delta' pour remplir jusqu'à aujourd'hui")

	return nil
}
