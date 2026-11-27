-- Documentos legais (idempotente)
INSERT INTO documento_legal (id, tipo, numero, ano, ementa, data_publicacao) VALUES
(1, 'DECRETO-LEI', '2848', 1940, 'Código Penal', '1940-12-31'),
(2, 'LEI', '12737', 2012, 'Dispõe sobre a tipificação criminal de delitos informáticos', '2012-12-03'),
(3, 'LEI', '14155', 2021, 'Altera o Decreto-Lei nº 2.848/1940 (Código Penal)', '2021-05-28')
ON CONFLICT (id) DO NOTHING;

-- Dispositivo: Art. 154-A (caput)
INSERT INTO dispositivo (id, documento_id, tipo, identificador, dispositivo_pai_id)
VALUES (154, 1, 'ARTIGO', 'Art. 154-A', NULL)
ON CONFLICT (id) DO NOTHING;

-- Carga histórica do Art. 154-A (executa apenas se ainda não houver versões para o dispositivo 154)
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM versao_texto WHERE dispositivo_id = 154) THEN
        -- Versão 1: Lei 12.737/2012 (vacatio legis de 120 dias -> vigência em 02/04/2013)
        INSERT INTO versao_texto
            (dispositivo_id, texto, lei_alteradora_id, tipo_alteracao, data_inicio_vigencia, data_fim_vigencia)
        VALUES (
            154,
            'Pena - detenção, de 3 (três) meses a 1 (um) ano, e multa.',
            2,
            'REDACAO_ORIGINAL',
            '2013-04-02',
            NULL
        );

        -- Emenda atômica: Lei 14.155/2021 (vigência em 28/05/2021 -> encerra anterior em 27/05/2021)
        PERFORM id FROM versao_texto
        WHERE dispositivo_id = 154 AND data_fim_vigencia IS NULL
        FOR UPDATE;

        UPDATE versao_texto
        SET data_fim_vigencia = '2021-05-27'
        WHERE dispositivo_id = 154 AND data_fim_vigencia IS NULL;

        INSERT INTO versao_texto
            (dispositivo_id, texto, lei_alteradora_id, tipo_alteracao, data_inicio_vigencia, data_fim_vigencia)
        VALUES (
            154,
            'Pena - reclusão, de 1 (um) a 4 (quatro) anos, e multa.',
            3,
            'NOVA_REDACAO',
            '2021-05-28',
            NULL
        );
    END IF;
END;
$$ LANGUAGE plpgsql;

-- Testes funcionais (C1 a C4)
SELECT 'C1' AS teste, fn_texto_na_data(154, '2013-04-02') AS resultado
UNION ALL
SELECT 'C2', fn_texto_na_data(154, '2015-05-10')
UNION ALL
SELECT 'C3', fn_texto_na_data(154, '2013-04-01')
UNION ALL
SELECT 'C4', fn_texto_na_data(154, CURRENT_DATE);

-- Testes de integridade (R1 a R4) — descomente um por vez para validar os bloqueios:
-- R1 (Sobreposição -> Erro 23P01):
-- INSERT INTO versao_texto (dispositivo_id, texto, tipo_alteracao, data_inicio_vigencia, data_fim_vigencia)
-- VALUES (154, 'Conflito', 'NOVA_REDACAO', '2015-01-01', '2016-01-01');

-- R2 (Duplo NULL -> Erro 23P01):
-- INSERT INTO versao_texto (dispositivo_id, texto, tipo_alteracao, data_inicio_vigencia, data_fim_vigencia)
-- VALUES (154, 'Duplo aberto', 'NOVA_REDACAO', '2025-01-01', NULL);

-- R3 (Adulteração de histórico via UPDATE -> Bloqueado por Trigger):
-- UPDATE versao_texto SET texto = 'Adulterado' WHERE dispositivo_id = 154;

-- R4 (Exclusão física -> Bloqueado por Trigger):
-- DELETE FROM versao_texto WHERE dispositivo_id = 154;
-- TRUNCATE TABLE versao_texto;
