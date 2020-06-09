-- ASSERT: no rows is ok. 
SELECT * FROM (
  select *,crp.from_cep(cep) AS crp_calc from crp.sample
) t 
WHERE crp_calc != crp;

