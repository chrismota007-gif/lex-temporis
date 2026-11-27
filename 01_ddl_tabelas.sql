-- Extensão necessária para restrição de exclusão combinando inteiro (=) e intervalo (&&)
CREATE EXTENSION IF NOT EXISTS btree_gist;

CREATE TABLE IF NOT EXISTS documento_legal (
    id SERIAL PRIMARY KEY,
    tipo VARCHAR(50) NOT NULL,
    numero VARCHAR(20) NOT NULL,
    ano INT NOT NULL,
    ementa TEXT,
    data_publicacao DATE NOT NULL,
    UNIQUE (tipo, numero, ano)
);

CREATE TABLE IF NOT EXISTS dispositivo (
    id SERIAL PRIMARY KEY,
    documento_id INT NOT NULL,
    tipo VARCHAR(50) NOT NULL,
    identificador VARCHAR(50) NOT NULL,
    dispositivo_pai_id INT,
    FOREIGN KEY (documento_id) REFERENCES documento_legal(id) ON DELETE RESTRICT,
    FOREIGN KEY (dispositivo_pai_id) REFERENCES dispositivo(id) ON DELETE RESTRICT
);

CREATE TABLE IF NOT EXISTS versao_texto (
    id SERIAL PRIMARY KEY,
    dispositivo_id INT NOT NULL,
    texto TEXT NOT NULL,
    lei_alteradora_id INT,
    tipo_alteracao VARCHAR(50) NOT NULL,
    data_inicio_vigencia DATE NOT NULL,
    data_fim_vigencia DATE,
    FOREIGN KEY (dispositivo_id) REFERENCES dispositivo(id) ON DELETE RESTRICT,
    FOREIGN KEY (lei_alteradora_id) REFERENCES documento_legal(id) ON DELETE RESTRICT,
    CHECK (
        tipo_alteracao IN ('REDACAO_ORIGINAL', 'NOVA_REDACAO',
                           'ALTERACAO_PARCIAL', 'REVOGACAO')
    ),
    CHECK (
        data_fim_vigencia >= data_inicio_vigencia
        OR data_fim_vigencia IS NULL
    )
);

-- Impede sobreposição temporal (e duplo NULL) + cria automaticamente o índice GiST
DO $$ BEGIN IF NOT EXISTS ( SELECT 1 FROM pg_constraint WHERE conname = 'sem_sobreposicao' AND conrelid = 'versao_texto'::regclass ) THEN ALTER TABLE versao_texto ADD CONSTRAINT sem_sobreposicao EXCLUDE USING gist ( dispositivo_id WITH =, daterange( data_inicio_vigencia, COALESCE(data_fim_vigencia, 'infinity'::date), '[]' ) WITH && ); END IF; END; $$ LANGUAGE plpgsql;
