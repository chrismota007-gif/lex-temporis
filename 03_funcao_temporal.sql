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
