-- Limpeza idempotente de gatilhos anteriores
DROP TRIGGER IF EXISTS trg_no_delete ON versao_texto;
DROP TRIGGER IF EXISTS trg_no_truncate ON versao_texto;
DROP TRIGGER IF EXISTS trg_no_update_texto ON versao_texto;
DROP TRIGGER IF EXISTS trg_no_update_historico ON versao_texto;

-- 1. Bloqueio de exclusão física (DELETE e TRUNCATE)
CREATE OR REPLACE FUNCTION trg_bloqueia_delete()
RETURNS TRIGGER AS $$
BEGIN
    RAISE EXCEPTION 'Violação de Imutabilidade: É proibido excluir ou truncar o histórico legislativo.';
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_no_delete
BEFORE DELETE ON versao_texto
FOR EACH ROW EXECUTE FUNCTION trg_bloqueia_delete();

CREATE TRIGGER trg_no_truncate
BEFORE TRUNCATE ON versao_texto
FOR EACH STATEMENT EXECUTE FUNCTION trg_bloqueia_delete();

-- 2. Proteção de campos históricos e bloqueio de reabertura de vigências encerradas
CREATE OR REPLACE FUNCTION trg_protege_historico()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.id IS DISTINCT FROM OLD.id
       OR NEW.dispositivo_id IS DISTINCT FROM OLD.dispositivo_id
       OR NEW.texto IS DISTINCT FROM OLD.texto
       OR NEW.lei_alteradora_id IS DISTINCT FROM OLD.lei_alteradora_id
       OR NEW.tipo_alteracao IS DISTINCT FROM OLD.tipo_alteracao
       OR NEW.data_inicio_vigencia IS DISTINCT FROM OLD.data_inicio_vigencia
    THEN
        RAISE EXCEPTION 'Violação de Auditoria: Campos históricos são imutáveis.';
    END IF;

    IF OLD.data_fim_vigencia IS NOT NULL
       AND NEW.data_fim_vigencia IS DISTINCT FROM OLD.data_fim_vigencia
    THEN
        RAISE EXCEPTION 'Violação de Auditoria: Uma vigência encerrada não pode ser alterada ou reaberta.';
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_no_update_historico
BEFORE UPDATE ON versao_texto
FOR EACH ROW EXECUTE FUNCTION trg_protege_historico();
