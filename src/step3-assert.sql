-- ASSERT: no rows is ok. 
\echo  '\n----\nListagem de erros:'

SELECT * FROM (
  select *,crp.from_cep(cep) AS crp_calc from crp.sample
) t
WHERE crp_calc != crp;

\echo  '(é esperada uma tabela vazia)\n----\n'
