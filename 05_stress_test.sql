-- 1. Carga massiva idempotente: 1 milhão de versões contíguas (janelas de 10 dias) no dispositivo 999
INSERT INTO documento_legal (id, tipo, numero, ano, ementa, data_publicacao)
VALUES (1, 'DECRETO-LEI', '2848', 1940, 'Código Penal', '1940-12-31')
ON CONFLICT (id) DO NOTHING;

INSERT INTO dispositivo (id, documento_id, tipo, identificador, dispositivo_pai_id)
VALUES (999, 1, 'ARTIGO', 'Art. Benchmark', NULL)
ON CONFLICT (id) DO NOTHING;

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM versao_texto WHERE dispositivo_id = 999) THEN
        INSERT INTO versao_texto
            (dispositivo_id, texto, tipo_alteracao, data_inicio_vigencia, data_fim_vigencia)
        SELECT
            999,
            'Texto de carga massiva ' || i,
            CASE WHEN i = 1 THEN 'REDACAO_ORIGINAL' ELSE 'NOVA_REDACAO' END,
            DATE '1000-01-01' + ((i - 1) * 10),
            CASE WHEN i < 1000000
                 THEN DATE '1000-01-01' + (i * 10) - 1
                 ELSE NULL
            END
        FROM generate_series(1, 1000000) AS i;
    END IF;
END;
$$ LANGUAGE plpgsql;

VACUUM ANALYZE versao_texto;

-- 2. Inspeção do plano de execução com índice GiST (sem_sobreposicao)
EXPLAIN (ANALYZE, BUFFERS)
SELECT texto
FROM versao_texto
WHERE dispositivo_id = 999
  AND daterange(
        data_inicio_vigencia,
        COALESCE(data_fim_vigencia, 'infinity'::date),
        '[]'
      ) @> (DATE '1000-01-01' + 5000000);

-- 3. Benchmark de 1.000 consultas aleatórias (p50, p95 e p99)
DO $$
DECLARE
    v_base   DATE := DATE '1000-01-01';
    v_data   DATE;
    v_texto  TEXT;
    v_inicio TIMESTAMPTZ;
    v_fim    TIMESTAMPTZ;
    v_tempos DOUBLE PRECISION[] := ARRAY[]::DOUBLE PRECISION[];
    v_p50    DOUBLE PRECISION;
    v_p95    DOUBLE PRECISION;
    v_p99    DOUBLE PRECISION;
BEGIN
    FOR k IN 1..1000 LOOP
        v_data := v_base + floor(random() * 10000000)::INT;
        v_inicio := clock_timestamp();

        SELECT texto INTO v_texto
        FROM versao_texto
        WHERE dispositivo_id = 999
          AND daterange(
                data_inicio_vigencia,
                COALESCE(data_fim_vigencia, 'infinity'::date),
                '[]'
              ) @> v_data;

        v_fim := clock_timestamp();
        v_tempos := array_append(
            v_tempos,
            EXTRACT(EPOCH FROM (v_fim - v_inicio)) * 1000.0
        );
    END LOOP;

    SELECT
        percentile_cont(0.50) WITHIN GROUP (ORDER BY t),
        percentile_cont(0.95) WITHIN GROUP (ORDER BY t),
        percentile_cont(0.99) WITHIN GROUP (ORDER BY t)
    INTO v_p50, v_p95, v_p99
    FROM unnest(v_tempos) AS t;

    RAISE NOTICE 'Benchmark (1000 consultas no dispositivo 999): p50 = % ms | p95 = % ms | p99 = % ms',
        round(v_p50::numeric, 3), round(v_p95::numeric, 3), round(v_p99::numeric, 3);
END;
$$ LANGUAGE plpgsql;

-- 4. Comparativo sem uso de índices (Parallel Seq Scan)
BEGIN;
SET LOCAL enable_indexscan = off;
SET LOCAL enable_bitmapscan = off;

EXPLAIN (ANALYZE, BUFFERS)
SELECT texto
FROM versao_texto
WHERE dispositivo_id = 999
  AND daterange(
        data_inicio_vigencia,
        COALESCE(data_fim_vigencia, 'infinity'::date),
        '[]'
      ) @> (DATE '1000-01-01' + 5000000);
COMMIT;
