package main

import (
	"context"
	"database/sql"
	"fmt"
	"log"
	"os"
	"os/signal"
	"sync"
	"sync/atomic"
	"syscall"
	"time"

	_ "github.com/lib/pq"

	kingpin "github.com/alecthomas/kingpin/v2"

	"github.com/IBM/sarama"
)

var (
	brokerList        = kingpin.Flag("brokerList", "List of brokers to connect").Default("kafka:9092").Strings()
	topic             = kingpin.Flag("topic", "Topic name").Default("votes").String()
	groupID           = kingpin.Flag("group", "Consumer group ID").Default("worker-group").String()
	messageCountStart = kingpin.Flag("messageCountStart", "Message counter start from:").Int()
)

const (
	host     = "postgresql"
	port     = 5432
	user     = "okteto"
	password = "okteto"
	dbname   = "votes"
)

// ---------------------------------------------------------------------------
// Circuit Breaker (DbWriteCircuitBreaker)
// States: Closed (normal) → Open (failing) → Half-Open (probing)
// ---------------------------------------------------------------------------

type CircuitState int

const (
	StateClosed   CircuitState = iota
	StateOpen
	StateHalfOpen
)

type CircuitBreaker struct {
	mu               sync.Mutex
	state            CircuitState
	failureCount     int
	failureThreshold int
	successThreshold int
	successCount     int
	lastFailure      time.Time
	openTimeout      time.Duration
}

func NewCircuitBreaker(failureThreshold, successThreshold int, openTimeout time.Duration) *CircuitBreaker {
	return &CircuitBreaker{
		state:            StateClosed,
		failureThreshold: failureThreshold,
		successThreshold: successThreshold,
		openTimeout:      openTimeout,
	}
}

func (cb *CircuitBreaker) Call(fn func() error) error {
	cb.mu.Lock()
	switch cb.state {
	case StateOpen:
		if time.Since(cb.lastFailure) > cb.openTimeout {
			cb.state = StateHalfOpen
			cb.successCount = 0
			fmt.Println("[CircuitBreaker] State: HALF-OPEN (probing)")
		} else {
			cb.mu.Unlock()
			return fmt.Errorf("circuit breaker is OPEN – call rejected")
		}
	}
	cb.mu.Unlock()

	err := fn()

	cb.mu.Lock()
	defer cb.mu.Unlock()
	if err != nil {
		cb.failureCount++
		cb.lastFailure = time.Now()
		if cb.failureCount >= cb.failureThreshold {
			cb.state = StateOpen
			fmt.Printf("[CircuitBreaker] State: OPEN after %d failures\n", cb.failureCount)
		}
		return err
	}

	// success path
	if cb.state == StateHalfOpen {
		cb.successCount++
		if cb.successCount >= cb.successThreshold {
			cb.state = StateClosed
			cb.failureCount = 0
			fmt.Println("[CircuitBreaker] State: CLOSED (recovered)")
		}
	} else {
		cb.failureCount = 0
	}
	return nil
}

// ---------------------------------------------------------------------------
// VoteStoreAdapter – wraps PostgreSQL writes behind the Circuit Breaker
// ---------------------------------------------------------------------------

type VoteStoreAdapter struct {
	db *sql.DB
	cb *CircuitBreaker
}

func NewVoteStoreAdapter(db *sql.DB, cb *CircuitBreaker) *VoteStoreAdapter {
	return &VoteStoreAdapter{db: db, cb: cb}
}

func (s *VoteStoreAdapter) PersistVote(voterID, vote string) error {
	return s.cb.Call(func() error {
		stmt := `INSERT INTO votes(id, vote) VALUES($1, $2) ON CONFLICT(id) DO UPDATE SET vote = $2`
		_, err := s.db.Exec(stmt, voterID, vote)
		return err
	})
}

// ---------------------------------------------------------------------------
// VoteTaskConsumer – Competing Consumers via Sarama ConsumerGroup
// ---------------------------------------------------------------------------

type VoteTaskConsumer struct {
	store        *VoteStoreAdapter
	messageCount int64
}

func (c *VoteTaskConsumer) Setup(sarama.ConsumerGroupSession) error   { return nil }
func (c *VoteTaskConsumer) Cleanup(sarama.ConsumerGroupSession) error { return nil }

func (c *VoteTaskConsumer) ConsumeClaim(session sarama.ConsumerGroupSession, claim sarama.ConsumerGroupClaim) error {
	for msg := range claim.Messages() {
		count := atomic.AddInt64(&c.messageCount, 1)
		voterID := string(msg.Key)
		vote := string(msg.Value)

		if voterID == "" {
			voterID = fmt.Sprintf("anon-%d", count)
		}

		fmt.Printf("[Replica] Received message #%d: user %s vote %s (partition %d)\n",
			count, voterID, vote, msg.Partition)

		if err := c.store.PersistVote(voterID, vote); err != nil {
			fmt.Printf("[Replica] Error persisting vote: %v\n", err)
		}

		session.MarkMessage(msg, "")
	}
	return nil
}

// ---------------------------------------------------------------------------

func main() {
	kingpin.Parse()

	db := openDatabase()
	defer db.Close()
	pingDatabase(db)

	createTableStmt := `CREATE TABLE IF NOT EXISTS votes (id VARCHAR(255) NOT NULL UNIQUE, vote VARCHAR(255) NOT NULL)`
	if _, err := db.Exec(createTableStmt); err != nil {
		log.Panic(err)
	}

	// DbWriteCircuitBreaker: opens after 5 failures, probes after 10s, needs 2 successes to close
	cb := NewCircuitBreaker(5, 2, 10*time.Second)
	store := NewVoteStoreAdapter(db, cb)

	// Competing Consumers: each replica joins the same consumer group "worker-group"
	group := getKafkaConsumerGroup()
	defer group.Close()

	handler := &VoteTaskConsumer{store: store}

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	// Consume in a loop (rebalance-safe)
	go func() {
		for {
			if err := group.Consume(ctx, []string{*topic}, handler); err != nil {
				fmt.Printf("[ConsumerGroup] Error: %v\n", err)
			}
			if ctx.Err() != nil {
				return
			}
		}
	}()

	fmt.Println("Worker is running (consumer group: " + *groupID + "). Press Ctrl+C to exit.")

	sigCh := make(chan os.Signal, 1)
	signal.Notify(sigCh, os.Interrupt, syscall.SIGTERM)
	<-sigCh

	fmt.Println("Interrupt received, shutting down...")
	cancel()
	log.Printf("Processed %d messages\n", atomic.LoadInt64(&handler.messageCount))
}

func openDatabase() *sql.DB {
	psqlconn := fmt.Sprintf("host=%s port=%d user=%s password=%s dbname=%s sslmode=disable", host, port, user, password, dbname)
	for {
		db, err := sql.Open("postgres", psqlconn)
		if err == nil {
			return db
		}
	}
}

func pingDatabase(db *sql.DB) {
	fmt.Println("Waiting for postgresql...")
	for {
		if err := db.Ping(); err == nil {
			fmt.Println("Postgresql connected!")
			return
		}
	}
}

func getKafkaConsumerGroup() sarama.ConsumerGroup {
	config := sarama.NewConfig()
	config.Consumer.Return.Errors = true
	config.Consumer.Offsets.Initial = sarama.OffsetOldest
	config.Consumer.Group.Rebalance.GroupStrategies = []sarama.BalanceStrategy{sarama.NewBalanceStrategyRoundRobin()}

	brokers := *brokerList
	fmt.Println("Waiting for kafka...")
	for {
		group, err := sarama.NewConsumerGroup(brokers, *groupID, config)
		if err == nil {
			fmt.Println("Kafka connected! Consumer group: " + *groupID)
			return group
		}
	}
}
