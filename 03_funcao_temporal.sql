-- Função principal de recuperação pontual (RF3) usando o índice GiST (sem_sobreposicao)
CREATE OR REPLACE FUNCTION fn_texto_na_data(
    p_disp_id INT, p_data DATE
)
RETURNS TEXT AS $$
DECLARE
    v_texto TEXT;
BEGIN
    SELECT texto INTO v_texto
    FROM versao_texto
    WHERE dispositivo_id = p_disp_id
      AND daterange(
            data_inicio_vigencia,
            COALESCE(data_fim_vigencia, 'infinity'::date),
            '[]'
          ) @> p_data;
    RETURN v_texto;
END;
$$ LANGUAGE plpgsql STABLE;

-- Extensões estruturais opcionais (RF4 e RF5 — suporte para trabalhos futuros)
CREATE OR REPLACE FUNCTION fn_comparar_versoes(
    p_disp_id INT, p_data_a DATE, p_data_b DATE
)
RETURNS TABLE(texto_data_a TEXT, texto_data_b TEXT) AS $$
    SELECT fn_texto_na_data(p_disp_id, p_data_a),
           fn_texto_na_data(p_disp_id, p_data_b);
$$ LANGUAGE sql STABLE;

CREATE OR REPLACE FUNCTION fn_versoes_no_intervalo(
    p_disp_id INT, p_inicio DATE, p_fim DATE
)
RETURNS TABLE(
    versao_id INT, texto TEXT,
    data_inicio_vigencia DATE, data_fim_vigencia DATE
) AS $$
    SELECT id, texto, data_inicio_vigencia, data_fim_vigencia
    FROM versao_texto
    WHERE dispositivo_id = p_disp_id
      AND daterange(
            data_inicio_vigencia,
            COALESCE(data_fim_vigencia, 'infinity'::date),
            '[]'
          ) && daterange(p_inicio, p_fim, '[]')
    ORDER BY data_inicio_vigencia;
$$ LANGUAGE sql STABLE;
