package main

import (
	"context"
	"crypto/sha256"
	"flag"
	"fmt"
	"log"
	"os"
	"os/signal"
	"runtime"
	"sync"
	"sync/atomic"
	"syscall"
	"time"
)

type config struct {
	cpuWorkers int
	memoryMiB  int
	stepMiB    int
	stepEvery  time.Duration
	duration   time.Duration
	probePath  string
}

func main() {
	cfg := parseFlags()
	if err := validate(cfg); err != nil {
		log.Fatal(err)
	}

	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()
	if cfg.duration > 0 {
		var cancel context.CancelFunc
		ctx, cancel = context.WithTimeout(ctx, cfg.duration)
		defer cancel()
	}

	if cfg.probePath != "" {
		probe(cfg.probePath)
	}

	log.Printf("pid=%d cpu_workers=%d memory_target=%dMiB duration=%s", os.Getpid(), cfg.cpuWorkers, cfg.memoryMiB, cfg.duration)

	var iterations atomic.Uint64
	var allocated atomic.Int64
	var wg sync.WaitGroup

	for range cfg.cpuWorkers {
		wg.Add(1)
		go burnCPU(ctx, &wg, &iterations)
	}

	wg.Add(1)
	go holdMemory(ctx, &wg, cfg, &allocated)

	report(ctx, &iterations, &allocated)
	wg.Wait()
	log.Printf("stopped: %v", ctx.Err())
}

func parseFlags() config {
	var cfg config
	flag.IntVar(&cfg.cpuWorkers, "cpu-workers", 1, "number of busy CPU goroutines (0 disables CPU load)")
	flag.IntVar(&cfg.memoryMiB, "memory-mib", 64, "memory to allocate and retain (0 disables memory load)")
	flag.IntVar(&cfg.stepMiB, "step-mib", 8, "memory allocated per step")
	flag.DurationVar(&cfg.stepEvery, "step-every", 250*time.Millisecond, "delay between allocation steps")
	flag.DurationVar(&cfg.duration, "duration", 0, "stop after this duration (0 runs until signalled)")
	flag.StringVar(&cfg.probePath, "probe-path", "", "try to read a path and report only whether it was accessible")
	flag.Parse()
	return cfg
}

func validate(cfg config) error {
	if cfg.cpuWorkers < 0 || cfg.memoryMiB < 0 {
		return fmt.Errorf("cpu-workers and memory-mib must be non-negative")
	}
	if cfg.memoryMiB > 0 && (cfg.stepMiB <= 0 || cfg.stepEvery <= 0) {
		return fmt.Errorf("step-mib and step-every must be positive when memory load is enabled")
	}
	if cfg.duration < 0 {
		return fmt.Errorf("duration must be non-negative")
	}
	return nil
}

func burnCPU(ctx context.Context, wg *sync.WaitGroup, iterations *atomic.Uint64) {
	defer wg.Done()
	var seed [sha256.Size]byte
	copy(seed[:], "resource-burner")
	for {
		select {
		case <-ctx.Done():
			return
		default:
			seed = sha256.Sum256(seed[:])
			iterations.Add(1)
		}
	}
}

func holdMemory(ctx context.Context, wg *sync.WaitGroup, cfg config, allocated *atomic.Int64) {
	defer wg.Done()
	if cfg.memoryMiB == 0 {
		<-ctx.Done()
		return
	}

	const mib = 1024 * 1024
	blocks := make([][]byte, 0, (cfg.memoryMiB+cfg.stepMiB-1)/cfg.stepMiB)
	for total := 0; total < cfg.memoryMiB; {
		step := min(cfg.stepMiB, cfg.memoryMiB-total)
		block := make([]byte, step*mib)
		for page := 0; page < len(block); page += 4096 {
			block[page] = byte(page)
		}
		blocks = append(blocks, block)
		total += step
		allocated.Store(int64(total))

		select {
		case <-ctx.Done():
			runtime.KeepAlive(blocks)
			return
		case <-time.After(cfg.stepEvery):
		}
	}

	<-ctx.Done()
	runtime.KeepAlive(blocks)
}

func report(ctx context.Context, iterations *atomic.Uint64, allocated *atomic.Int64) {
	ticker := time.NewTicker(time.Second)
	defer ticker.Stop()
	for {
		select {
		case <-ctx.Done():
			return
		case <-ticker.C:
			log.Printf("allocated=%dMiB hash_iterations=%d", allocated.Load(), iterations.Load())
		}
	}
}

func probe(path string) {
	data, err := os.ReadFile(path)
	if err != nil {
		log.Printf("probe path=%q readable=false error=%v", path, err)
		return
	}
	log.Printf("probe path=%q readable=true bytes=%d", path, len(data))
}
