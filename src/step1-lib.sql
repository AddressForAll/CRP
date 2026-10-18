--
-- Implantação SQL do algoritmo CRP. Ver https://github.com/AddressForAll/CRP 
-- Complementado por steps 2 a 3.
--

DROP SCHEMA IF EXISTS crp CASCADE;
CREATE SCHEMA crp;


-- -- -- --
-- public lib:

CREATE or replace FUNCTION array_first_notnull(a anyarray) RETURNS anyelement AS $f$
  SELECT x FROM unnest(a) t(x) WHERE x IS NOT NULL;
$f$ LANGUAGE SQL IMMUTABLE;

CREATE or replace FUNCTION array_count_first_notnull(
  a anyarray, x ANYELEMENT = NULL
) RETURNS int AS $f$
  DECLARE
  s int := 0;
  BEGIN
  IF a IS NULL THEN RETURN 0; END IF;
  FOREACH x IN ARRAY $1
  LOOP
    s := s + 1;
    EXIT WHEN x is not null;
  END LOOP;
  RETURN s;
  END
$f$ LANGUAGE PLpgSQL IMMUTABLE;

CREATE TABLE crp.sample (
  crp text NOT NULL,
  cep text NOT NULL,
  UNIQUE(crp,cep)
);
-- -- -- --
-- MAIN lib

-- CEP <-> CRP (PostgreSQL / PL/pgSQL)
-- 
-- No CRP as siglas não são exatamente UFs, devido à partição de SP: 
--   ZM substitui o primeiro dígito 0 do CEP;
--   SP substitui o primeiro dígito 1.

CREATE OR REPLACE FUNCTION crp.from_cep(cep text)
RETURNS text AS $f$
DECLARE
    m text[];
    i int;
    uf text;
    pref text;
    -- RO: captura somente 76, exigindo 8 ou 9 em seguida.
    -- Isso explicita a faixa 768/769 sem mudar os CRPs existentes.
    prefMain_rgx CONSTANT text :=
        '^(699|693|689|69|65|64|79|78|77|76(?=[89])|59|58|57|5|49|4|29|2|9|3|1|0)';
    prefExtra_rgx CONSTANT text :=
        '^(?:(6[0-3])|(6(?:[67][0-9]|8[0-8]))|(7(?:3[0-6]|[01]|2[0-7]))|(7(?:2[8-9]|3[7-9]|[45]|6[0-7]))|(8[0-7])|(8[8-9]))';
    prefExtra2UF_dg CONSTANT text[] := ARRAY['6','6','7','7','8','8'];
    prefExtra2UF CONSTANT text[] := ARRAY['CE','PA','DF','GO','PR','SC'];
    prefMain2uf CONSTANT jsonb := '{
        "0":"ZM", "1":"SP", "2":"RJ", "3":"MG", "4":"BA",
        "5":"PE", "9":"RS", "29":"ES", "49":"SE", "57":"AL",
        "58":"PB", "59":"RN", "64":"PI", "65":"MA", "69":"AM",
        "76":"RO", "77":"TO", "78":"MT", "79":"MS",
        "689":"AP", "693":"RR", "699":"AC"
    }'::jsonb;
BEGIN
    cep := trim(cep);
    -- Aceita somente oito dígitos ou o formato 00000-000.
    -- Mantém a convenção original de retorno de erro em from_cep.
    IF cep IS NULL OR cep !~ '^[0-9]{5}-?[0-9]{3}$' THEN
        RETURN '(ERRO 1)';
    END IF;
    cep := replace(cep, '-', '');

    m := regexp_match(cep, prefExtra_rgx);
    IF m IS NOT NULL THEN
        FOR i IN 1..6 LOOP
            IF m[i] IS NOT NULL THEN
                uf := prefExtra2UF[i];
                pref := prefExtra2UF_dg[i];
                EXIT;
            END IF;
        END LOOP;
    ELSE
        m := regexp_match(cep, prefMain_rgx);
        IF m IS NULL THEN
            RETURN '(ERRO 2)';
        END IF;
        pref := m[1];
        uf := prefMain2uf ->> pref;
    END IF;

    RETURN uf || substr(cep, length(pref) + 1, 5 - length(pref))
              || '-' || substr(cep, 6);
END;
$f$ LANGUAGE plpgsql IMMUTABLE;

COMMENT ON FUNCTION crp.from_cep(text)
IS 'Encodes CEP as CRP; returns (ERRO 1) for invalid input or (ERRO 2) for unknown prefix';


CREATE OR REPLACE FUNCTION crp.from_cep(cep int)
RETURNS text AS $wrap$
    -- Evita que lpad trunque inteiros com mais de oito dígitos.
    SELECT CASE
        WHEN cep IS NULL OR cep < 0 OR cep > 99999999 THEN '(ERRO 1)'
        ELSE crp.from_cep(lpad(cep::text, 8, '0'))
    END;
$wrap$ LANGUAGE sql IMMUTABLE;

COMMENT ON FUNCTION crp.from_cep(int)
IS 'Encodes integer CEP as CRP, restoring leading zeros';


CREATE OR REPLACE FUNCTION crp.to_cep(
    p_crp text,
    p_compact boolean DEFAULT false
) RETURNS text AS $f$
DECLARE
    v_crp text;
    v_uf text;
    v_pref text;
    v_cep text;
    v_uf2pref CONSTANT jsonb := '{
        "AC":"699", "RR":"693", "AP":"689",
        "AM":"69", "MA":"65", "PI":"64",
        "MS":"79", "MT":"78", "TO":"77", "RO":"76",
        "RN":"59", "PB":"58", "AL":"57", "PE":"5",
        "SE":"49", "BA":"4", "ES":"29", "RJ":"2",
        "RS":"9", "MG":"3", "SP":"1", "ZM":"0",
        "CE":"6", "PA":"6", "DF":"7", "GO":"7",
        "PR":"8", "SC":"8"
    }'::jsonb;
BEGIN
    v_crp := upper(trim(p_crp));
    IF v_crp IS NULL OR v_crp = '' THEN
        RAISE EXCEPTION 'ERROR-4: CRP vazio';
    END IF;
    v_uf := left(v_crp, 2);
    v_pref := v_uf2pref ->> v_uf;
    IF v_pref IS NULL THEN
        RAISE EXCEPTION 'ERROR-5: CRP % com prefixo % desconhecido', p_crp, v_uf;
    END IF;
    IF v_crp !~ '^[A-Z]{2}[0-9]{2,4}-?[0-9]{3}$' THEN
        RAISE EXCEPTION 'ERROR-6: formato de CRP inválido: %', p_crp;
    END IF;
    v_crp := replace(v_crp, '-', '');
    v_cep := v_pref || substr(v_crp, 3);
    IF length(v_cep) <> 8 THEN
        RAISE EXCEPTION 'ERROR-7: quantidade de dígitos inválida para o prefixo %', v_uf;
    END IF;
    IF replace(crp.from_cep(v_cep), '-', '') IS DISTINCT FROM v_crp THEN
        RAISE EXCEPTION 'ERROR-8: CRP % incompatível com as faixas de crp.from_cep', p_crp;
    END IF;
    IF p_compact THEN
        RETURN v_cep;
    END IF;
    RETURN left(v_cep, 5) || '-' || right(v_cep, 3);
END;
$f$ LANGUAGE plpgsql IMMUTABLE;

COMMENT ON FUNCTION crp.to_cep(text, boolean)
IS 'Decodes CRP as CEP, validating consistency with crp.from_cep; true returns eight digits';

-- Exemplos:
-- SELECT crp.to_cep('ES000-000');       -- 29000-000
-- SELECT crp.to_cep('AC00-000');        -- 69900-000
-- SELECT crp.to_cep('ZM1000-000');      -- 01000-000
-- SELECT crp.from_cep('01000-000');     -- ZM1000-000
-- SELECT crp.from_cep('10000-000');     -- SP0000-000
-- SELECT crp.to_cep('SP0000-000');      -- 10000-000
-- SELECT crp.to_cep('ce0000000', true); -- 60000000
-- SELECT crp.from_cep('76799-999');     -- GO6799-999
-- SELECT crp.from_cep('76800-000');     -- RO800-000
-- SELECT crp.from_cep('76999-999');     -- RO999-999
-- SELECT crp.to_cep('RO000-000');      -- ERROR-8 (76000-000 -> GO)

-- Teste opcional de ida e volta: deve retornar zero linhas.
-- Testa os 100.000 prefixos de cinco dígitos, com dois sufixos cada.
-- SELECT cep
-- FROM (
--     SELECT lpad(n::text, 5, '0') || s AS cep
--     FROM generate_series(0, 99999) AS g(n)
--     CROSS JOIN (VALUES ('000'), ('999')) AS sufixos(s)
-- ) AS amostra
-- WHERE crp.to_cep(crp.from_cep(cep), true) IS DISTINCT FROM cep;
