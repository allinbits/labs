package main

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"github.com/jackc/pgx/v5"
	"log"
	"math"
	"os"
	"regexp"
	"strings"

	cid "github.com/ipfs/go-cid"
	"github.com/jackc/pgx/v5/pgxpool"
	mh "github.com/multiformats/go-multihash"
)

// -----------------------------------------------------------------------------
// Minimal config
// -----------------------------------------------------------------------------

var (
	// Example: "postgres://postgres:postgres@localhost:5432/logograph?sslmode=disable"
	pgURL = envOr("DATABASE_URL", "postgres://postgres:postgres@localhost:5432/logograph?sslmode=disable")

	// Embedding model name we store alongside vectors (swap with your real one)
	embedModel = "bge-small-en-v1.5"
	// Embedding dimension (must match your model)
	embedDim = 384
)

// -----------------------------------------------------------------------------
// Schema bootstrap
// -----------------------------------------------------------------------------

const schemaSQL = `
-- Extensions
CREATE EXTENSION IF NOT EXISTS vector;
-- Optional; keep if you've installed it:  CREATE EXTENSION IF NOT EXISTS pg_bm25;
-- Optional; JSON schema validation:       CREATE EXTENSION IF NOT EXISTS pg_jsonschema;

-- Objects table
CREATE TABLE IF NOT EXISTS lg_object (
  cid         text PRIMARY KEY,
  realm       text NOT NULL,
  path        text NOT NULL,
  media_type  text,
  sha256_hex  text NOT NULL,
  bytes_len   integer NOT NULL,
  json_ld     jsonb,
  created_at  timestamptz DEFAULT now(),
  UNIQUE (realm, path, cid)
);

-- Chunks (normalized text)
CREATE TABLE IF NOT EXISTS lg_chunk (
  chunk_id    text PRIMARY KEY,              -- cid#offset
  cid         text NOT NULL REFERENCES lg_object(cid) ON DELETE CASCADE,
  ordinal     integer NOT NULL,
  byte_start  integer NOT NULL,
  byte_end    integer NOT NULL,
  text        text NOT NULL,
  lang        text,
  tsv         tsvector
);
CREATE INDEX IF NOT EXISTS lg_chunk_tsv_gin ON lg_chunk USING GIN (tsv);

-- Embeddings
CREATE TABLE IF NOT EXISTS lg_embedding (
  chunk_id    text PRIMARY KEY REFERENCES lg_chunk(chunk_id) ON DELETE CASCADE,
  model       text NOT NULL,
  dim         int  NOT NULL,
  embedding   vector NOT NULL
);
CREATE INDEX IF NOT EXISTS lg_embedding_hnsw_cos ON lg_embedding USING hnsw (embedding vector_cosine_ops);

-- Optional graph edges
CREATE TABLE IF NOT EXISTS lg_edge (
  src_cid     text NOT NULL REFERENCES lg_object(cid) ON DELETE CASCADE,
  dst_cid     text NOT NULL REFERENCES lg_object(cid) ON DELETE CASCADE,
  rel         text NOT NULL,
  PRIMARY KEY (src_cid, dst_cid, rel)
);
`

// -----------------------------------------------------------------------------
// Models
// -----------------------------------------------------------------------------

type LGObject struct {
	CID       string
	Realm     string
	Path      string
	MediaType string
	SHA256Hex string
	BytesLen  int
	JSONLD    any
}

type LGChunk struct {
	ChunkID   string
	CID       string
	Ordinal   int
	ByteStart int
	ByteEnd   int
	Text      string
	Lang      string
}

// -----------------------------------------------------------------------------
// CID helpers (CIDv1, codec=raw, hash=sha2-256)
// -----------------------------------------------------------------------------

func computeCIDv1RawSha256(b []byte) (cidStr, shaHex string, err error) {
	sum := sha256.Sum256(b)
	shaHex = hex.EncodeToString(sum[:])
	m, err := mh.Encode(sum[:], mh.SHA2_256)
	if err != nil {
		return "", "", err
	}
	// 0x55 is "raw" multicodec
	c := cid.NewCidV1(0x55, m)
	return c.String(), shaHex, nil
}

// -----------------------------------------------------------------------------
// Chunking (deterministic-ish): split by sentences; fallback to fixed window
// -----------------------------------------------------------------------------

var sentenceRX = regexp.MustCompile(`(?ms)([^.!?\n]+[.!?]|[^\n]+(?:\n|$))`)

func chunkText(cid string, original []byte, lang string, targetMin, targetMax int) ([]LGChunk, error) {
	// Extract text conservatively (assume UTF-8 text for demo)
	txt := string(original)
	// Sentences
	sents := sentenceRX.FindAllString(txt, -1)
	if len(sents) == 0 {
		sents = []string{txt}
	}

	// Greedy pack into target size window
	var chunks []LGChunk
	var cur strings.Builder
	byteStart := 0
	ordinal := 0

	flush := func(end int) {
		if cur.Len() == 0 {
			return
		}
		ordinal++
		chunkID := fmt.Sprintf("%s#%06d", cid, ordinal)
		ch := LGChunk{
			ChunkID:   chunkID,
			CID:       cid,
			Ordinal:   ordinal,
			ByteStart: byteStart,
			ByteEnd:   end,
			Text:      cur.String(),
			Lang:      lang,
		}
		chunks = append(chunks, ch)
		cur.Reset()
		byteStart = end
	}

	bytePos := 0
	for _, s := range sents {
		if cur.Len() < targetMin || (cur.Len()+len(s) <= targetMax) {
			cur.WriteString(s)
			bytePos += len(s)
		} else {
			flush(bytePos)
			cur.WriteString(s)
			bytePos += len(s)
		}
	}
	flush(bytePos)

	return chunks, nil
}

// -----------------------------------------------------------------------------
// Embeddings: stub (replace with real embedder). Must return slice[dim]float32.
// -----------------------------------------------------------------------------

func embed(text string) ([]float32, error) {
	// TODO: plug your model (OpenAI/Cohere/local-bge). For now, simple hash->vector.
	v := make([]float32, embedDim)
	if text == "" {
		return v, nil
	}
	h := sha256.Sum256([]byte(strings.ToLower(text)))
	for i := 0; i < embedDim; i++ {
		// spread 32 hash bytes across the vector
		b := h[i%32]
		// map to [-1,1]
		v[i] = (float32(int(b))-127.5)/127.5 + smallJitter(i)
	}
	// L2 normalize for cosine
	n := float32(0)
	for _, x := range v {
		n += x * x
	}
	n = float32(math.Sqrt(float64(n))) + 1e-9
	for i := range v {
		v[i] /= n
	}
	return v, nil
}

func smallJitter(i int) float32 { return float32((i%7)-3) * 0.0001 }

// -----------------------------------------------------------------------------
// DB ops
// -----------------------------------------------------------------------------

func ensureSchema(ctx context.Context, db *pgxpool.Pool) error {
	_, err := db.Exec(ctx, schemaSQL)
	return err
}

func upsertObject(ctx context.Context, db *pgxpool.Pool, obj LGObject) error {
	_, err := db.Exec(ctx, `
INSERT INTO lg_object(cid, realm, path, media_type, sha256_hex, bytes_len, json_ld)
VALUES ($1,$2,$3,$4,$5,$6,$7)
ON CONFLICT (cid) DO NOTHING
`, obj.CID, obj.Realm, obj.Path, obj.MediaType, obj.SHA256Hex, obj.BytesLen, toJSONB(obj.JSONLD))
	return err
}

func insertChunks(ctx context.Context, db *pgxpool.Pool, chunks []LGChunk) error {
	batch := &pgx.Batch{}
	for _, c := range chunks {
		batch.Queue(`
INSERT INTO lg_chunk(chunk_id, cid, ordinal, byte_start, byte_end, text, lang)
VALUES ($1,$2,$3,$4,$5,$6,$7)
ON CONFLICT (chunk_id) DO NOTHING`,
			c.ChunkID, c.CID, c.Ordinal, c.ByteStart, c.ByteEnd, c.Text, c.Lang)
	}
	br := db.SendBatch(ctx, batch)
	defer br.Close()
	for range chunks {
		if _, err := br.Exec(); err != nil {
			return err
		}
	}
	// Materialize tsv (simple demo: english stemming, weight B)
	_, err := db.Exec(ctx, `
UPDATE lg_chunk SET tsv = setweight(to_tsvector('english', coalesce(text,'')), 'B')
WHERE tsv IS NULL`)
	return err
}

func insertEmbeddings(ctx context.Context, db *pgxpool.Pool, chunks []LGChunk) error {
	batch := &pgx.Batch{}
	for _, c := range chunks {
		vec, err := embed(c.Text)
		if err != nil {
			return err
		}
		batch.Queue(`
INSERT INTO lg_embedding(chunk_id, model, dim, embedding)
VALUES ($1,$2,$3,$4)
ON CONFLICT (chunk_id) DO UPDATE SET model = EXCLUDED.model, dim = EXCLUDED.dim, embedding = EXCLUDED.embedding`,
			c.ChunkID, embedModel, embedDim, vecToPG(vec))
	}
	br := db.SendBatch(ctx, batch)
	defer br.Close()
	for range chunks {
		if _, err := br.Exec(); err != nil {
			return err
		}
	}
	return nil
}

func vecToPG(v []float32) string {
	sb := strings.Builder{}
	sb.WriteString("[")
	for i, x := range v {
		if i > 0 {
			sb.WriteString(",")
		}
		// pgvector accepts plain decimals
		sb.WriteString(fmt.Sprintf("%g", x))
	}
	sb.WriteString("]")
	return sb.String()
}

// -----------------------------------------------------------------------------
// Hybrid search (lexical + vector cosine) with realm filter
// -----------------------------------------------------------------------------

type SearchHit struct {
	ChunkID     string
	CID         string
	LexScore    float64
	VecScore    float64
	HybridScore float64
	Text        string
}

func hybridSearch(ctx context.Context, db *pgxpool.Pool, query string, realms []string, wLex, wVec float64, k int) ([]SearchHit, error) {
	if k <= 0 {
		k = 20
	}
	// Create query embedding (replace with same model as embed())
	qVec, _ := embed(query)

	rows, err := db.Query(ctx, `
WITH
q AS (
  SELECT $1::text                        AS qtext,
         $2::text[]                      AS realms,
         $3::float8                      AS wlex,
         $4::float8                      AS wvec,
         $5::vector                      AS qvec
),
lex AS (
  SELECT c.chunk_id, c.cid,
         ts_rank(c.tsv, plainto_tsquery((SELECT qtext FROM q))) AS lex_score
  FROM lg_chunk c
  JOIN lg_object o ON o.cid = c.cid
  WHERE (SELECT CASE WHEN array_length((SELECT realms FROM q),1) IS NULL THEN TRUE ELSE o.realm = ANY((SELECT realms FROM q)) END)
  ORDER BY lex_score DESC
  LIMIT 200
),
vec AS (
  SELECT e.chunk_id, ch.cid,
         (1 - (e.embedding <=> (SELECT qvec FROM q))) AS vec_score
  FROM lg_embedding e
  JOIN lg_chunk ch ON ch.chunk_id = e.chunk_id
  JOIN lg_object o  ON o.cid = ch.cid
  WHERE (SELECT CASE WHEN array_length((SELECT realms FROM q),1) IS NULL THEN TRUE ELSE o.realm = ANY((SELECT realms FROM q)) END)
  ORDER BY e.embedding <=> (SELECT qvec FROM q)
  LIMIT 200
),
u AS (
  SELECT COALESCE(l.chunk_id, v.chunk_id) AS chunk_id,
         COALESCE(l.cid, v.cid)           AS cid,
         COALESCE(l.lex_score, 0)         AS lex_score,
         COALESCE(v.vec_score, 0)         AS vec_score
  FROM lex l FULL OUTER JOIN vec v USING (chunk_id)
)
SELECT u.chunk_id, u.cid, u.lex_score, u.vec_score,
       ((SELECT wlex FROM q)*u.lex_score + (SELECT wvec FROM q)*u.vec_score) AS hybrid_score,
       c.text
FROM u
JOIN lg_chunk c ON c.chunk_id = u.chunk_id
ORDER BY hybrid_score DESC
LIMIT $6`,
		query, stringArrayOrNull(realms), wLex, wVec, vecToPG(qVec), k,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var out []SearchHit
	for rows.Next() {
		var h SearchHit
		if err := rows.Scan(&h.ChunkID, &h.CID, &h.LexScore, &h.VecScore, &h.HybridScore, &h.Text); err != nil {
			return nil, err
		}
		out = append(out, h)
	}
	return out, rows.Err()
}

func stringArrayOrNull(ss []string) any {
	if len(ss) == 0 {
		return nil
	}
	return ss
}

// -----------------------------------------------------------------------------
// Ingest demo: one JSON-LD text object (swap with your gno.land reader)
// -----------------------------------------------------------------------------

func ingestCIDObject(ctx context.Context, db *pgxpool.Pool, realm, path, mediaType string, raw []byte, jsonLD any, lang string) (string, error) {
	c, sha, err := computeCIDv1RawSha256(raw)
	if err != nil {
		return "", err
	}
	obj := LGObject{
		CID:       c,
		Realm:     realm,
		Path:      path,
		MediaType: mediaType,
		SHA256Hex: sha,
		BytesLen:  len(raw),
		JSONLD:    jsonLD,
	}
	if err := upsertObject(ctx, db, obj); err != nil {
		return "", err
	}
	// Chunk
	chunks, err := chunkText(c, raw, lang, 600, 1200)
	if err != nil {
		return "", err
	}
	if err := insertChunks(ctx, db, chunks); err != nil {
		return "", err
	}
	if err := insertEmbeddings(ctx, db, chunks); err != nil {
		return "", err
	}
	return c, nil
}

// -----------------------------------------------------------------------------
// Utilities
// -----------------------------------------------------------------------------

func toJSONB(v any) []byte {
	if v == nil {
		return nil
	}
	b, _ := json.Marshal(v)
	return b
}

func envOr(k, def string) string {
	if v := os.Getenv(k); v != "" {
		return v
	}
	return def
}

// -----------------------------------------------------------------------------
// main: wire up schema, ingest a sample, run a hybrid query
// -----------------------------------------------------------------------------

func main() {
	ctx := context.Background()
	pool, err := pgxpool.New(ctx, pgURL)
	must(err)
	defer pool.Close()

	must(ensureSchema(ctx, pool))

	// Demo payload: pretend this came from gno.land realm/path
	jsonLD := map[string]any{
		"@context": "https://schema.org",
		"@type":    "Article",
		"name":     "Logograph: CID-first semantic objects",
		"about":    []string{"Petri nets", "Gno.land", "CID", "RAG", "Provenance"},
	}
	text := `
Logograph is a CID-backed registry of semantic objects designed for reproducible builds and credible provenance.
Objects are ingested from gno.land realms, normalized into text chunks, and indexed with Postgres FTS and pgvector.
This enables hybrid retrieval (lexical + vector) while preserving verifiable source CIDs for every snippet.
`

	cidStr, err := ingestCIDObject(ctx, pool,
		"gno.land/r/stackdump000", "/objects/logograph-intro", "text/plain; charset=utf-8",
		[]byte(text), jsonLD, "en")
	must(err)
	log.Printf("ingested CID: %s", cidStr)

	// Run a hybrid query
	hits, err := hybridSearch(ctx, pool, "CID provenance for hybrid RAG on Postgres", []string{"gno.land/r/stackdump000"}, 0.6, 0.4, 10)
	must(err)

	log.Println("Top results:")
	for i, h := range hits {
		fmt.Printf("%2d) %s  CID=%s  score=%.4f\n    %s\n\n", i+1, h.ChunkID, h.CID, h.HybridScore, oneLine(h.Text))
	}
}

func oneLine(s string) string {
	s = strings.TrimSpace(s)
	s = strings.Join(strings.Fields(s), " ")
	const n = 140
	if len(s) > n {
		return s[:n] + "…"
	}
	return s
}

func must(err error) {
	if err != nil && !errors.Is(err, context.Canceled) {
		log.Fatal(err)
	}
}
