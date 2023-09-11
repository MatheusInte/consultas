-- SELECTS
Select * from atividade
Select * from certificado
Select * from curso
Select * from endereco
Select * from requisicao
Select * from usuario

-- RF 13: CADASTRAR REQUISIÇÃO
CREATE OR REPLACE FUNCTION get_id_curso(p_id_usuario BIGINT)
RETURNS BIGINT AS $$
DECLARE
	id_curso BIGINT;
BEGIN
	SELECT curso.id INTO id_curso FROM usuario JOIN curso ON usuario.curso_id = curso.id
	WHERE usuario.id = p_id_usuario;
	RETURN id_curso;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION get_id_atividade(p_descricao VARCHAR(255))
RETURNS BIGINT AS $$
DECLARE
	id_atividade BIGINT;
BEGIN
	SELECT atividade.id FROM atividade WHERE atividade.descricao = p_descricao INTO id_atividade;
	RETURN id_atividade;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION checar_certificado(p_requisicao_id BIGINT, p_id_atividade BIGINT, p_carga_horaria REAL, p_titulo VARCHAR(255))
RETURNS BOOL AS $$

DECLARE
	count INTEGER;
	id_usuario BIGINT;

BEGIN
	SELECT usuario_id FROM requisicao WHERE requisicao.id = p_requisicao_id INTO id_usuario;
	
	SELECT COUNT(*) FROM requisicao JOIN certificado ON requisicao.id = certificado.requisicao_id
	WHERE requisicao.usuario_id = id_usuario AND certificado.atividade_id = p_id_atividade AND certificado.carga_horaria = p_carga_horaria
	AND certificado.titulo = p_titulo INTO count;
	
	IF count > 0 THEN
		RETURN True;
	END IF;
	
	RETURN False;
	
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION cadastrar_requisicao(p_usuario_id BIGINT)
RETURNS void AS $$
DECLARE
	id_curso BIGINT;
	id_next BIGINT;
BEGIN
    IF p_usuario_id IS NULL THEN
        RAISE EXCEPTION 'Informe o ID do usuário em questão';
    END IF;
	
	SELECT COALESCE(MAX(id), 0) + 1 FROM requisicao INTO id_next;
	
	SELECT get_id_curso(p_usuario_id) INTO id_curso;
	
    INSERT INTO requisicao (id, usuario_id, curso_id, arquivada, criacao, status_requisicao)
    VALUES (id_next, p_usuario_id, id_curso, False, NOW(), 'RASCUNHO');
END;
$$
LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION adicionar_certificado(p_requisicao_id BIGINT, p_descricao_atividade VARCHAR(255), p_carga_horaria REAL, p_titulo VARCHAR(255))
RETURNS void AS $$
DECLARE 
	id_next BIGINT;
	id_atividade BIGINT;
BEGIN
	IF p_requisicao_id IS NULL THEN
		RAISE EXCEPTION 'Informe o ID da requisição';
	END IF;
	
	SELECT COALESCE(MAX(id), 0) + 1 FROM certificado INTO id_next;
	
	SELECT get_id_atividade(p_descricao_atividade) INTO id_atividade;
	
	IF (SELECT checar_certificado(p_requisicao_id, id_atividade, p_carga_horaria, p_titulo)) is TRUE THEN
		RAISE EXCEPTION 'Esse certificado provavelmente já foi adicionado';
	END IF;
	
	INSERT INTO certificado(
		id, atividade_id, requisicao_id, carga_horaria, data_inicial, status_certificado, titulo
	)
	VALUES (id_next, id_atividade, p_requisicao_id, p_carga_horaria, NOW(), 'RASCUNHO', p_titulo);
END;
$$
LANGUAGE plpgsql;


-- RF 14: CONSULTAR LISTA DE REQUISIÇÕES
REATE OR REPLACE FUNCTION consultar_requisicoes(p_id_usuario BIGINT)
RETURNS TABLE (status_requisicao VARCHAR(255), id_requisicao VARCHAR(255)) AS $$
BEGIN
    RETURN QUERY SELECT requisicao.status_requisicao, requisicao.id_requisicao BIGINT FROM requisicao WHERE requisicao.usuario_id = p_id_usuario
	AND requisicao.arquivada = False;
END;
$$ LANGUAGE plpgsql;

SELECT * FROM consultar_requisicoes(130); --Consultando todas as requisicões não-arquivadas do usuario 130


-- RF 15: FILTRAR REQUISIÇÕES
CREATE OR REPLACE FUNCTION filtrar_certificados_eixo(p_id_usuario BIGINT, p_eixo VARCHAR(15))
RETURNS TABLE (titulo VARCHAR(255), eixo VARCHAR(15), carga_horaria REAL) AS $$
BEGIN
	IF p_id_usuario IS NULL AND p_eixo IS NULL THEN
		RAISE EXCEPTION 'Insira parâmetros';
	END IF;
	
    RETURN QUERY
	SELECT certificado.titulo, atividade.eixo, certificado.carga_horaria FROM certificado 
	JOIN requisicao ON certificado.requisicao_id = requisicao.id
	JOIN atividade ON certificado.atividade_id = atividade.id
	WHERE requisicao.usuario_id = p_id_usuario AND atividade.eixo = p_eixo;
END;
$$ LANGUAGE plpgsql;

DROP FUNCTION filtrar_certificados_eixo(bigint, character varying);

SELECT * FROM filtrar_certificados_eixo(493,'PESQUISA'); --Filtrando certificados do usuario 493 de acordo pelo eixo pesquisa


-- RF 17: VISUALISAR INDICADORES SOBRE AS REQUISIÇÕES ENVIADAS
CREATE OR REPLACE FUNCTION verificar_status_requisicao(p_id_requisicao BIGINT)
RETURNS VARCHAR(30) AS $$
DECLARE 
	status VARCHAR(30);
BEGIN
    SELECT status_requisicao FROM requisicao WHERE id = p_id_requisicao INTO status;
	RETURN status;
END;
$$ LANGUAGE plpgsql;

SELECT verificar_status_requisicao(50); --Verificando o status de uma requisicao específica

CREATE OR REPLACE FUNCTION quantidade_rascunho(p_id_usuario BIGINT)
RETURNS INTEGER AS $$
DECLARE 
	total INTEGER;
BEGIN
    SELECT count(status_requisicao) FROM requisicao WHERE usuario_id = p_id_usuario AND status_requisicao = 'RASCUNHO' INTO total;
	RETURN total;
END;
$$ LANGUAGE plpgsql;

DROP FUNCTION quantidade_rascunho(bigint);

SELECT quantidade_rascunho(11); --Verificando a quantidade de rascunhos que um aluno tem

CREATE OR REPLACE FUNCTION horas_eixo(p_usuario_id BIGINT, p_eixo VARCHAR(15))
RETURNS REAL AS $$
DECLARE
    total REAL;
BEGIN
    CASE
        WHEN p_eixo = 'ENSINO' THEN
            SELECT horas_ensino INTO total FROM usuario WHERE id = p_usuario_id;
        WHEN p_eixo = 'PESQUISA' THEN
            SELECT horas_pesquisa INTO total FROM usuario WHERE id = p_usuario_id;
        WHEN p_eixo = 'EXTENSAO' THEN
            SELECT horas_extensao INTO total FROM usuario WHERE id = p_usuario_id;
        WHEN p_eixo = 'GESTAO' THEN
            SELECT horas_gestao INTO total FROM usuario WHERE id = p_usuario_id;
        ELSE
            total := 0;
    END CASE;

    RETURN total;
END;
$$ LANGUAGE plpgsql;

SELECT horas_ensino, horas_pesquisa, horas_extensao, horas_gestao FROM usuario WHERE usuario.id = 297; --Olhando na tabela as horas pra verificar se a função ta certa

SELECT horas_eixo(297, 'ENSINO'); --Testando olhar a horas validadas de ENSINO pro aluno 297


-- RF 18: CRIAR RASCUNHO DE REQUISIÇÃO


-- RF 19: DELETAR RASCUNHO DE REQUISIÇÃO
CREATE OR REPLACE FUNCTION visualizar_rascunhos(p_usuario_id BIGINT)
RETURNS TABLE (id BIGINT, status_requisicao VARCHAR(30)) AS $$
BEGIN
    RETURN QUERY SELECT requisicao.id, requisicao.status_requisicao FROM requisicao
	WHERE usuario_id = p_usuario_id AND requisicao.status_requisicao = 'RASCUNHO';
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION deletar_rascunho(p_usuario_id BIGINT, p_requisicao_id BIGINT)
RETURNS void AS $$
BEGIN
	DELETE FROM certificado
	WHERE certificado.requisicao_id = p_requisicao_id;
	
    DELETE FROM requisicao
	WHERE requisicao.usuario_id = p_usuario_id AND requisicao.id = p_requisicao_id AND requisicao.status_requisicao = 'RASCUNHO';
	RAISE NOTICE 'Rascunho Apagado!';
END;
$$ LANGUAGE plpgsql;

SELECT cadastrar_requisicao(11); --Cadastra um rascunho

SELECT * FROM visualizar_rascunhos(11); --Visualiza os rascunhos disponíves

SELECT deletar_rascunho(11, 1309); --Deleta o rascunho que você quer
SELECT * FROM visualizar_rascunhos(11);


-- RF 20: ALTERAR RASCUNHO DE REQUISIÇÃO

/*
A função abaixo recebe como parâmetros o id de um certificado
e os novos valores para os dados deste certificado. Os dados 
só serão atualizados se o status da solicitação à qual
este certificado está associado for "RASCUNHO"
*/

create or replace function alterar_rascunho2(
	id_cert integer,
	new_cert bytea,
	new_ch real,
	new_df date,
	new_di date,
	new_obs text,
	new_title character varying (255),
	new_atv_id bigint
)
returns void as $$
begin
	update certificado set
		certificado = new_cert,
		carga_horaria = new_ch,
		data_final = new_df,
		data_inicial = new_di,
		observacao = new_obs,
		titulo = new_title,
		atividade_id = new_atv_id
	from requisicao where
		certificado.requisicao_id = requisicao.id
		and requisicao.status_requisicao = 'RASCUNHO'
		and certificado.id = id_cert;
end; $$
language plpgsql;



-- RF 21: ENVIAR SOLICITAÇÃO À COORDENAÇÃO

/*
A função abaixo recebe como parâmetro o id de uma requisição e,
primeiramente, modifica o status da requisição para "TRANSITO". 
Após isso, todos os certificados que estiverem associados à essa
requisição terão o seu status modificado para "ENCAMINHADO_COORDENACAO"
*/

create or replace function atualizar_status_req(id_req integer)
returns void as $$
begin
	update requisicao
	set status_requisicao = 'TRANSITO'
	where id = id_req;
	PERFORM atualizar_certificados(id_req);
end; $$
language plpgsql;

create or replace function atualizar_certificados(id_req integer)
returns void as $$
begin
	update certificado
	set status_certificado = 'ENCAMINHADO_COORDENACAO'
	where requisicao_id = id_req;
end; $$
language plpgsql;



-- RF 22: ALTERAR SOLICITAÇÃO

/*
A função abaixo recebe como parâmetros o id de um certificado
e os novos valores para os dados deste certificado. Os dados 
só serão atualizados se o status da solicitação à qual
este certificado está associado for "PROBLEMA" ou "NEGADO"
*/

create or replace function alterar_solicitacao2(
	id_cert integer,
	new_cert bytea,
	new_ch real,
	new_df date,
	new_di date,
	new_obs text,
	new_title character varying (255),
	new_atv_id bigint
)
returns void as $$
begin
	update certificado set
		certificado = new_cert,
		carga_horaria = new_ch,
		data_final = new_df,
		data_inicial = new_di,
		observacao = new_obs,
		titulo = new_title,
		atividade_id = new_atv_id
	from requisicao where
		certificado.requisicao_id = requisicao.id
		and (requisicao.status_requisicao = 'PROBLEMA'
			 or requisicao.status_requisicao = 'NEGADO')
		and certificado.id = id_cert;
end; $$
language plpgsql;


-- RF 23: VISUALIZAR DADOS DO DISCENTE

/*
A função abaixo recebe como parâmetro o id de um usuário
(discente) e retorna uma tabela que contém os dados referentes
à quantidade de horas complementares registradas para esse
discente nos eixos ensino, extensão, gestão e pesquisa
*/

create or replace function extrato_horas(id_disc integer)
returns table (
	Ensino real,
	Extensao real,
	Gestao real,
	Pesquisa real
) as $$
begin
	return query select
	horas_ensino, horas_extensao, horas_gestao, horas_pesquisa
	from usuario where id = id_disc;
end;
$$ language plpgsql;


-- RF 24: VISUALIZAR FLUXO DA REQUISIÇÃO

/*
A função abaixo recebe como parâmetro o id de uma requisição
e retorna uma tabela que contém os dados referentes
à requisição pesquisada, como o id, status e descrição
*/

CREATE OR REPLACE FUNCTION visualizar_fluxo_requisicao(p_id_requisicao BIGINT)
RETURNS TABLE(requisicao_id BIGINT, status_requisicao VARCHAR(30), descricao_requisicao TEXT) AS $$
BEGIN
	RETURN QUERY SELECT requisicao.id, requisicao.status_requisicao, requisicao.observacao FROM requisicao
	WHERE requisicao.id = p_id_requisicao;
END;
$$ LANGUAGE plpgsql;

DROP FUNCTION visualizar_fluxo_requisicao(BIGINT)

SELECT * FROM visualizar_fluxo_requisicao(431)



-- RF 26: VISUALIZAÇÃO DE PERFIL 

/*
A função abaixo recebe como parâmetro o id de um usuário (discente)
e retorna uma tabela que contém os dados referentes
ao usuário selecionado, como o nome completo, matrícula, email, tipo do perfil e telefone
*/

CREATE OR REPLACE FUNCTION visualizar_perfil(p_usuario_id BIGINT)
RETURNS TABLE (nome_completo VARCHAR(255),matricula VARCHAR(255),email VARCHAR(255), perfil VARCHAR(255),telefone VARCHAR(255)) AS $$
BEGIN
	RETURN QUERY SELECT usuario.nome_completo, usuario.matricula, usuario.email, usuario.perfil, usuario.telefone FROM usuario
	WHERE usuario.id = p_usuario_id;
END;
$$ LANGUAGE plpgsql;

DROP FUNCTION visualizar_perfil(BIGINT)

SELECT * FROM visualizar_perfil(43)


-- RF 27: ARQUIVAR SOLICITAÇÃO

/*
A função abaixo recebe como parâmetro o id de um usuário (discente) e o id de uma requisição
e realiza a ação de modificar o status da requisição que contém o id do usuário para "arquivada" desde que ela não seja um rascunho.
*/


CREATE OR REPLACE FUNCTION arquivar_requisicao(p_usuario_id BIGINT, p_requisicao_id BIGINT)
RETURNS void AS $$
DECLARE 
	status_atual VARCHAR(255);

BEGIN	
	SELECT status_requisicao INTO status_atual FROM requisicao WHERE id = p_requisicao_id;

	IF status_atual != 'RASCUNHO' THEN
		UPDATE requisicao SET arquivada = true WHERE id = p_requisicao_id AND usuario_id = p_usuario_id;
		RAISE NOTICE 'Requisição Arquivada!';
	ELSE
		RAISE NOTICE 'A requisição não foi NEGADA!';
	END IF;
END;
$$ LANGUAGE plpgsql;


DROP FUNCTION arquivar_requisicao(BIGINT)

SELECT arquivar_requisicao(431,329)

SELECT arquivar_requisicao(431,808)


-- RF 28: DELETAR SOLICITAÇÃO

CREATE TABLE requisicao_lixeira (
    id BIGINT PRIMARY KEY,
	dia_de_delecao DATE,
    arquivada BOOLEAN,
    criacao DATE,
    data_submissao DATE,
    id_requisicao VARCHAR(255),
    observacao TEXT,
    requisicao_arquivo_assinada BYTEA,
    status_requisicao VARCHAR(255),
    token VARCHAR(255),
    curso_id BIGINT,
    usuario_id BIGINT
);

DROP TABLE requisicao_lixeira
SELECT * FROM requisicao_lixeira

/*
A função abaixo recebe como parâmetro o id de uma requisição e
realiza a função de inserir a requisição na tabela requisicao_lixeira junto com a data de deleção
e logo após deleta a requisição da tabela requisicao
*/

CREATE OR REPLACE FUNCTION deletar_requisicao(p_requisicao_id BIGINT)
RETURNS VOID AS $$
BEGIN

	-- Inserindo na lixeira
	INSERT INTO requisicao_lixeira (id, arquivada, criacao, data_submissao, id_requisicao, observacao, requisicao_arquivo_assinada, status_requisicao, token, curso_id, usuario_id)
	SELECT id, arquivada, criacao, data_de_submissao, id_requisicao,observacao, requisicao_arquivo_assinada, status_requisicao, token, curso_id, usuario_id
	FROM requisicao
	WHERE requisicao.id = p_requisicao_id;
	
	UPDATE requisicao_lixeira
	SET dia_de_delecao = current_date
	WHERE id = p_requisicao_id;
	
	-- Delentando da tabela requisição
	DELETE FROM requisicao WHERE id = p_requisicao_id;
	
	
END;
$$ LANGUAGE plpgsql;

DROP FUNCTION deletar_requisicao(bigint);

SELECT * FROM deletar_requisicao(250)


-- RF 30: MODAL LIXEIRA

/*
A função abaixo recebe como parâmetro o id do usuário (discente)
e retorna uma tabela contendo todas as requisições que possuem o id do usuário
selecionado na tabela requisicao_lixeira
*/

CREATE OR REPLACE FUNCTION modal_lixeira(p_usuario_id BIGINT)
RETURNS TABLE (
	id BIGINT,
	dia_de_delecao date,
	arquivada boolean,
	criacao date,
	data_submissao date,
	id_requisicao VARCHAR(255),
	observacao text,
	requisicao_arquivo_assinada bytea,
	status_requisicao VARCHAR(255),
	token VARCHAR(255),
	curso_id BIGINT,
	id_usuario BIGINT
) AS $$
BEGIN
	RETURN QUERY SELECT * FROM requisicao_lixeira WHERE usuario_id = p_usuario_id;
END;
$$ LANGUAGE plpgsql;

DROP FUNCTION modal_lixeira(BIGINT);

SELECT * FROM modal_lixeira(486);


-- CONSULTAS DO DASHBOARD
-- BOX: MINHAS HORAS POR EIXO

/*
Nesta consulta é feito uma função que recebe o id de um usuário como parâmetro e,
através de um select, pega a quantidade de horas que o mesmo possui em seus respectivos eixos.
Para demonstração foi escolhido o usuário de id = 96.
*/

CREATE OR REPLACE FUNCTION minhas_horas_por_eixo(id_referencia INT)
RETURNS TABLE (
	horas_ensino REAL,
	horas_extensao REAL,
	horas_gestao REAL,
	horas_pesquisa REAL
) AS $$
BEGIN
	RETURN QUERY
	SELECT usuario.horas_ensino, usuario.horas_extensao, usuario.horas_gestao, usuario.horas_pesquisa
	FROM usuario
	WHERE usuario.id = id_referencia;
END;
$$ LANGUAGE plpgsql;

SELECT * FROM minhas_horas_por_eixo(96);


-- BOX: TOP SOLICITAÇÕES

/*
Nesta consulta é feito uma função que recebe o id de um usuário como parâmetro e,
através de um select em uma junção de tabelas, pega a soma da quantidade de horas
que um usuário específico possui em suas respectivas requisições, bem como
a data de submissão e o id da mesma, ordenando a tabela em ordem decrescente após isso.
Vale lembrar que somente as requisições de status "ACEITAS" são contabilizadas.
Para demonstração foi escolhido o usuário de id = 469.
*/

SELECT id_requisicao, status_requisicao FROM requisicao WHERE usuario_id=469; --TESTE

CREATE OR REPLACE FUNCTION top_solicitacoes(id_referencia INT)
RETURNS TABLE (
	id_requisicao VARCHAR(255),
	data_de_submissao DATE,
	total_carga_horaria REAL
) AS $$
BEGIN
	RETURN QUERY
	SELECT subquery.id_requisicao, subquery.data_de_submissao, SUM(subquery.carga_horaria) AS total_carga_horaria
	FROM (
		SELECT * FROM requisicao
		INNER JOIN certificado ON requisicao.id=certificado.requisicao_id
	) AS subquery
	WHERE usuario_id=id_referencia AND status_requisicao='ACEITO'
	GROUP BY subquery.id_requisicao, subquery.data_de_submissao
	ORDER BY total_carga_horaria DESC;
END;
$$ LANGUAGE plpgsql;

SELECT * FROM top_solicitacoes(469);


-- BOX: SOLICITAÇÕES ARQUIVADAS

/*
Nesta consulta é feito uma função que recebe o id de um usuário como parâmetro e,
através de um select e da função COUNT(), pega a quantidade de requisições que
foram arquivadas por um usuário específico. Para demonstração foi escolhido o
usuário de id = 96.
*/

CREATE OR REPLACE FUNCTION total_solicitacoes_arquivadas(id_referencia INT)
RETURNS TABLE (
    total_arquivadas BIGINT
) AS $$
BEGIN
    RETURN QUERY
    SELECT COUNT(requisicao.arquivada) AS total_arquivadas
    FROM requisicao
    WHERE requisicao.usuario_id=id_referencia AND arquivada=true;
END;
$$ LANGUAGE plpgsql;

SELECT * FROM total_solicitacoes_arquivadas(96);

SELECT DISTINCT arquivada FROM requisicao; -- Não há solicitações arquivadas no banco


-- BOX: SOLICITAÇÕES ACEITAS
-- CONSIDERANDO DADOS DA REQUISIÇÃO

/*
Nesta consulta é feito uma função que recebe o id de um usuário como parâmetro e,
através de um select, seleciona requisições de um usuário específico que foram aceitas,
apresentando o id, a data de submissao e a soma das horas da mesma.
Para demonstração foi escolhido o usuário de id = 469.
*/

CREATE OR REPLACE FUNCTION solicitacoes_aceitas_0(id_referencia INT)
RETURNS TABLE (
	id_requisicao VARCHAR(255),
	data_de_submissao DATE,
	total_carga_horaria REAL
) AS $$
BEGIN
	RETURN QUERY
	SELECT subquery.id_requisicao, subquery.data_de_submissao, SUM(subquery.carga_horaria) AS total_carga_horaria
	FROM (
		SELECT * FROM requisicao
		INNER JOIN certificado ON requisicao.id=certificado.requisicao_id
	) AS subquery
	WHERE usuario_id=id_referencia AND status_requisicao='ACEITO'
	GROUP BY subquery.id_requisicao, subquery.data_de_submissao
	ORDER BY total_carga_horaria DESC;
END;
$$ LANGUAGE plpgsql;

SELECT * FROM solicitacoes_aceitas_0(469);

-- CONSIDERANDO DADOS DO CERTIFICADO

/*
Nesta consulta é feito uma função que recebe o id de uma requisição como parâmetro e,
através de um select em uma junção de tabelas, seleciona certificados de uma requisição específica,
apresentando o carga horária do certificado, a carga horária aceita por certificado no barema,
a carga horária máxima da atividade e o eixo da atividade.
Para demonstração foi escolhido o usuário de id = 1102.
*/

CREATE OR REPLACE FUNCTION detalhes_certificados(id_referencia INTEGER)
RETURNS TABLE (
	carga_horaria REAL,
	ch_por_certificado INTEGER,
	ch_maxima INTEGER,
	eixo VARCHAR(255)
) AS $$
BEGIN
	RETURN QUERY
	SELECT certificado.carga_horaria, atividade.ch_por_certificado,
		   atividade.ch_maxima, atividade.eixo
	FROM certificado
	INNER JOIN atividade ON certificado.atividade_id=atividade.id WHERE certificado.requisicao_id=id_referencia;
END;
$$ LANGUAGE plpgsql;

SELECT * FROM detalhes_certificados(1102);


-- BOX: SOLICITAÇÕES REJEITADAS

/*
Nesta consulta é feito uma função que recebe o id de um usuário como parâmetro e,
através de um select, seleciona requisições de um usuário específico que foram rejeitadas,
apresentando o id da mesma e sua observação.
Para demonstração foi escolhido o usuário de id = 96.
*/

CREATE OR REPLACE FUNCTION solicitacoes_rejeitadas(id_referencia INTEGER)
RETURNS TABLE (
	id_requisicao VARCHAR(255),
	observacao TEXT
) AS $$
BEGIN
	RETURN QUERY
	SELECT requisicao.id_requisicao, requisicao.observacao
	FROM requisicao
	WHERE status_requisicao='NEGADO' AND usuario_id=id_referencia;
END;
$$ LANGUAGE plpgsql;

SELECT * FROM solicitacoes_rejeitadas(96);

-- BOX: SOLICITAÇÕES REGISTRADAS POR ANO

/*
Nesta consulta é feito uma função que recebe o id de um usuário como parâmetro e,
através de um select e da função COUNT(), pega a quantidade de requisições que
foram feitas pelo mesmo agrupadas pelos seus respectivos anos.
Para demonstração foi escolhido o usuário de id = 96.

OBS: Não haviam informações suficientes para afirmar se todas as tentativas de submissões deveriam
ser contabilizadas ou apenas as ACEITAS deveriam. Na função feita apenas as requisições aceitas foram
contabilizadas.
*/

CREATE OR REPLACE FUNCTION solicitacoes_por_ano(id_referencia INTEGER)
RETURNS TABLE (
	ano_submissao NUMERIC,
	quantidade BIGINT
) AS $$
BEGIN
	RETURN QUERY
	SELECT EXTRACT(YEAR FROM data_de_submissao) AS ano_submissao, COUNT(*) AS COUNT
	FROM requisicao
	WHERE status_requisicao='ACEITO' AND usuario_id=id_referencia
	GROUP BY EXTRACT(YEAR FROM data_de_submissao);
END;
$$ LANGUAGE plpgsql;

SELECT * FROM solicitacoes_por_ano(96);

-- Select meramente ilustrativo pra mostrar que só há requisições de 2022 e 2023
SELECT DISTINCT EXTRACT(YEAR FROM data_de_submissao) FROM requisicao;


-- BOX: STATUS DAS SOLICITAÇÕES
SELECT id_requisicao, status_requisicao FROM requisicao WHERE usuario_id=469; -- TESTE

-- SOLICITAÇÕES ACEITAS

/*
Nesta consulta é feito uma função que recebe o id de um usuário como parâmetro e,
através de um select e da função COUNT(), pega a quantidade de requisições ACEITAS
de um usuário específico. Para demonstração foi escolhido o usuário de id = 469.
*/

CREATE OR REPLACE FUNCTION total_aceitas(id_referencia INTEGER)
RETURNS TABLE (
	quantidade_aceitas BIGINT
) AS $$
BEGIN
	RETURN QUERY
	SELECT COUNT(status_requisicao)
	FROM requisicao
	WHERE status_requisicao='ACEITO' AND usuario_id=id_referencia;
END;
$$ LANGUAGE plpgsql;

SELECT * FROM total_aceitas(469);

-- SOLICITAÇÕES NEGADAS

/*
Nesta consulta é feito uma função que recebe o id de um usuário como parâmetro e,
através de um select e da função COUNT(), pega a quantidade de requisições NEGADAS
de um usuário específico. Para demonstração foi escolhido o usuário de id = 469.
*/

CREATE OR REPLACE FUNCTION total_negadas(id_referencia INTEGER)
RETURNS TABLE (
	quantidade_negadas BIGINT
) AS $$
BEGIN
	RETURN QUERY
	SELECT COUNT(status_requisicao)
	FROM requisicao
	WHERE status_requisicao='NEGADO' AND usuario_id=id_referencia;
END;
$$ LANGUAGE plpgsql;

SELECT * FROM total_negadas(469);



























