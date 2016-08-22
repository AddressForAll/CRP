# CRP
Código de Roteamento Postal

-----

Os [algoritmos de mapeamento baseados em *faces de quadra*](https://en.wikipedia.org/wiki/Postal_code#Codes_defined_independently_from_administrative_borders) são relativamente simples e, com a  disponibilização dos [dados públicos de face de quadra pelo IBGE em 2016](https://lists.openstreetmap.org/pipermail/talk-br/2016-July/011502.html), tornaram-se viáveis.

Os códigos de CEP de 5 dígitos (`CEP5`) [são de domínio público](https://github.com/ppKrauss/licenses/blob/master/reports/implied-lex-BR-v1.md), como qualquer [outra norma técnica citada por lei](http://www.pessoacomdeficiencia.gov.br/app/normas-da-abnt/termo-de-ajustamento-de-conduta) no sistema legislativo brasileiro. Os [códigos de 8 dígitos](https://www.correios.com.br/para-voce/precisa-de-ajuda/o-que-e-cep-e-por-que-usa-lo/estrutura-do-cep) (`CEP8`) também, por [princípios de coerência legislativa e constitucionalidade](dx.doi.org/10.5281/zenodo.57253), deveriam ser.

A ETC (Empresa brasileira de Correios e Telégrafos), [reclamou direitos autorais](http://pt.stackoverflow.com/q/54539/4186) sobre o banco de dados oficial do `CEP8`: uma negociação da OSM com a [nova diretoria da ETC](http://www.osul.com.br/correios-reduzem-salario-da-diretoria/), ou uma [Ação Civil Pública](https://pt.wikipedia.org/wiki/A%C3%A7%C3%A3o_civil_p%C3%BAblica), podem resolver a situação, mas o encaminhamento coletivo está ainda no inicio, e o processso será certamente moroso.

Explicando melhor. O cidadão e as empresas brasileiras têm direito de uso do CEP como [dado aberto](https://en.wikipedia.org/wiki/Open_data) por ser o CEP uma norma requisitada por Lei, e portanto, automaticamente, uma obrigação do Estado a sua publicidade e expressão em domínio público, tal como os nomes de rua. O CEP é como qualquer outra tabela anexa a uma Lei, e o "dono do CEP" é a Câmara Municipal ("dona" dos nomes de rua e [autoridade das "leis de batismo"](http://www.lexml.gov.br/busca/search?keyword=denomina+via&f1-tipoDocumento=Legisla%C3%A7%C3%A3o)), que apenas delega o "batismo de CEP" aos Correios.

Para contornar esse problema,
> basta não utilizar o nome "CEP" e não reproduzir exatamente a *string* do `CEP8` num banco de dados ou listagem sistemática públicos dos códigos de CEPs.

O presente projeto é uma proposta de padronização simples para que a comunidade OSM possa trabalhar mais a vontade com os dados do CEP.

## Nome alternativo ao CEP

As principais aplicações do CEP nos dias de hoje (2016) estão vinculadas às finalidades logísticas. Neste sentido o termo "roteamento" (empregado por exemplo na Alemanha e na Suíça) pode ser adotado no lugar de "endereçamento". Este é o nexo para a sugestão do  nome alternativo **`CRP`**, abreviação de **Código de Roteamento Postal**.
<br/><small>NOTA: a ideia de "roteamento" no lugar de "endereçamento" ajuda inclusive a evitar confusão com termos como "endereço do lote" e "ponto de endereçamento" &mdash; o lote ou seu centroide pode ter mais de um CEP, ou seja, o lote pode ter mais de um portão para receber entregas.</small>

## String alternativa ao CEP
A representação do CEP não precisa ser um inteiro único para o Brasil, podem ser inteiros com unicidade garantida por unidade da federação (UF), de modo a termos em uma [base SQL](https://en.wikipedia.org/wiki/SQL) cada _string_ de CEP representada pela UF e um código dentro da UF, ou seja, com a unicidade garantida por `UNIQUE(uf,codigo)`. Podemos convencionar que a _string_ alternativa é então algo como o código da UF concatenado ao código restante do CEP. Por exemplo "SP12345-678".

Como na base de dados é mais econômico representar uma sequência de dígitos na forma de inteiro (uma [máscara simples de `printf`](https://en.wikipedia.org/wiki/Printf_format_string) converte de volta na _string_ padrão), uma tabela SQL de *códigos CRP* pode ser expressa como tabela PostgreSQL como por exemplo,


```sql
CREATE TABLE crp (
	prefix char(2) NOT NULL,	-- UF, letras CRP. REFERENCES state(uf).
	suffix int NOT NULL,   		-- dígitos CRP
	info  JSONb,        		-- demais informações desejadas.
	PRIMARY KEY (prefix,suffix)
);
```

Tendo isso em vista, a conversão entre CEP e CRP seria simples e facilmente reversível. Exemplos:

* Os CEPs de Minas Gerais ("30000-000" a "39999-999") seriam entradas com prefixo "MG" e sufixos variando de 0 a 9999999 (sete dígitos), ou seja, _strings_ representadas como "MG0000-000" a "MG9999-999". <br/>Para converter de CRP de volta para CEP basta trocar "MG" por "3".

* Os CEPs  do Maranhão ("65000-000" a "65999-999") seriam entradas com prefixo "MA" e sufixos variando de 0 a 999999 (seis dígitos), ou seja, _strings_ representadas como "MA000-000" a "MA999-999". <br/>Para converter de CRP de volta para CEP basta trocar "MA" por "65".

* Os CEPs  do Amazonas ("69000-000" a "69299-999" e "69400-000" a "69899-999") seriam entradas com prefixo "AM" e sufixos variando de 0 a 999999 (seis dígitos), ou seja, _strings_ representadas como "AM000-000" a "AM299-999" e "AM400-000" a "AM899-999". <br/>Para converter de CRP de volta para CEP basta trocar "AM" por "69".

A única excessão à regra do "nome do estado no prefixo" seria São Paulo, que tem uma conjunto de CEPs só para a zona metropolitana ("01000-000" a "09999-999"), o qual poderia ser batizado de "ZM".

A tabela completa, baseada na [lista geral dos CEPs](https://en.wikipedia.org/wiki/List_of_postal_codes_in_Brazil#Eight-digit_form), está em **[CEP-to-CRP.csv](data/CEP-to-CRP.csv)**, e define a rigor todos os detalhes da conversão entre *strings* de CEP e CRP.  O script PHP [convert.php](convert.php) exemplifica a implementação da conversão através de algoritmos simples.

## Extensibilidade e compactação
O formato CRM acima descrito também pode:

* ser estendido para uma segunda convenção OSM de "CEP de local sem CEP", ou seja, realizar um registro preliminar de CEP para locais tais como favelas, ocupação irregular e novos loteamentos. Convenções simples como concatenação  de uma letra podem ser usadas.

* ter seu código compactado, reduzido apenas à parte inteira (`CRP_int`), quando o contexto de UF (ou zona metropolitana) for conhecido.

## Propostas e objetivos

A proposta do presente projeto é simplesmente **estabelecer uma convenção para o armazenamento de dados de CEP nos mapas da OpenStreetmap-Brasil**, e demonstrar que a convenção é consistente, simples e reversível.

Num segundo momento, em um projeto muito mais amplo, denominado atualmente de *"Mapa do CEP"*, a proposta é de fato transcrever todos os dados de CEP do Brasil disponíveis para as bases de dados da OSM.

Desta maneira a presente proposta é independente, mas tem também por objetivo fomentar e criar subsídios para a implementação do Mapa do CEP.
