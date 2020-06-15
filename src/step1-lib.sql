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

/* 
CREATE or replace FUNCTION jsonb_object_valuekey(j jsonb) RETURNS jsonb AS $f$
   SELECT ('{'||string_agg('"'||value||'":"'||key||'"', ',') ||'}' )::jsonb 
   FROM jsonb_each_text(j)
$f$ LANGUAGE SQL IMMUTABLE;

SELECT string_agg(v,',') FROM  jsonb_each_text('{"CE":"6", "PA":"6", "DF":"7", "GO":"7", "PR":"8", "SC":"8"}'::jsonb) t(k,v);
--bug aspas: jsonb_path_query('{"CE":"6", "PA":"6", "DF":"7", "GO":"7", "PR":"8", "SC":"8"}'::jsonb,'$.*') t(x); 

SELECT * FROM jsonb_object_valuekey(
 '{"AC":699,"RR":693,"AP":689,"AM":69,"MA":65,"PI":64,"MS":79,"MT":78,"TO":77,"RO":76,"RN":59}'::jsonb
     || '{"PB":58,"AL":57,"PE":5,"SE":49,"BA":4,"ES":29,"RJ":2,"RS":9,"MG":3,"SP":1,"ZM":0}'::jsonb
) t(x);  -- bom nao repete
*/

/* RESULTADOS:
array[6,7,7,6,8,8];

'{"0":"ZM", "1": "SP", "2": "RJ", "3": "MG", "4": "BA", "5": "PE", "9": "RS"}'::jsonb
|| '{"29": "ES", "49": "SE", "57": "AL", "58": "PB", "59": "RN", "64": "PI", "65": "MA", "69": "AM", "76": "RO", "77": "TO", "78": "MT", "79": "MS"}'::jsonb
|| '{"689": "AP", "693": "RR", "699": "AC"}'::jsonb;
*/

CREATE TABLE crp.sample (
  crp text NOT NULL,
  cep text NOT NULL,
  UNIQUE(crp,cep)
);
-- -- -- --
-- MAIN lib


CREATE or replace FUNCTION crp.from_cep(cep text) RETURNS text AS $f$
  DECLARE
  m text[];
  aux int;
  uf text;
  pref text;
  prefMain_rgx  text =  '^(699|693|689|69|65|64|79|78|77|76|59|58|57|5|49|4|29|2|9|3|1|0)';
  prefExtra_rgx text =  '^(?:(6[0-3])|(6(?:[67][0-9]|8[0-8]))|(7(?:3[0-6]|[01]|2[0-7]))|(7(?:2[8-9]|3[7-9]|[45]|6[0-7]))|(8[0-7])|(8[8-9]))';
  prefExtra2UF_dg text[] = array['6', '6', '7', '7', '8', '8'];
  prefExtra2UF text[]    = array['CE','PA','DF','GO','PR','SC'];
  prefMain2uf  JSONb = '{"0":"ZM", "1":"SP", "2":"RJ", "3":"MG", "4":"BA", "5":"PE", "9":"RS", "29":"ES", "49":"SE", "57":"AL"}'::jsonb
                        || '{"58":"PB", "59":"RN", "64":"PI", "65":"MA", "69":"AM", "76":"RO", "77":"TO", "78":"MT", "79":"MS"}'::jsonb
                        || '{"689":"AP", "693":"RR", "699":"AC"}'::jsonb;
  BEGIN
  cep := trim(replace(cep,'-',''));
  IF cep is null OR length(cep)!=8  THEN
     RETURN '(ERRO 1)'; -- CEP vazio ou com tamanho inválido
  END IF;
  m := regexp_match(cep,prefExtra_rgx);
  aux := array_count_first_notnull(m);
  IF aux>0 THEN
    uf := prefExtra2UF[aux];
    pref = prefExtra2UF_dg[aux];
  ELSE
    BEGIN
    m := regexp_match(cep,prefMain_rgx);
	IF m is not NULL THEN
      pref := m[1];
      uf := prefMain2uf->>pref;
	ELSE
	  RETURN '(ERRO 2)'; -- prefixo nao encontrado
	END IF;
    END;
  END IF;
  RETURN regexp_replace(substr(cep,1,5), '^'||pref, uf) || '-' || substr(cep,6);
  END
$f$ LANGUAGE PLpgSQL IMMUTABLE;
COMMENT ON FUNCTION crp.from_cep(text) IS 'Encodes CEP as CRP';

CREATE or replace FUNCTION crp.from_cep(cep int) RETURNS text AS $wrap$
  SELECT crp.from_cep( lpad(cep::text,8,'0') )
$wrap$ LANGUAGE SQL IMMUTABLE;
COMMENT ON FUNCTION crp.from_cep(int) IS 'Encodes integer CEP as CRP';


