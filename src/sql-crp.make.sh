psql sandbox < src/step1-lib.sql
psql sandbox < src/step2-sample.sql
psql sandbox < src/step3-assert.sql

echo "... Agora executar as cargas de dados externos: OSM, IBGE, etc."
echo "... Por exemplo para IBGE executar ibge_cAgro17.make.sh se o ls abaixo vazio"
ls /tmp/agro/utf8/

