CREATE PROCEDURE [sankhya].[DAL_STP_EVT_CALCFRETECAB_PESO] (
       @P_TIPOEVENTO INTEGER,    -- Identifica o tipo de evento
       @P_IDSESSAO VARCHAR(MAX), -- Identificador da execu��o. Serve para buscar informa��es dos campos da execu��o.
       @P_CODUSU INTEGER         -- C�digo do usu�rio logado
) AS
DECLARE
	@BEFORE_INSERT   INTEGER,
    @AFTER_INSERT    INTEGER,
    @BEFORE_DELETE   INTEGER,
    @AFTER_DELETE    INTEGER,
    @BEFORE_UPDATE   INTEGER,
    @AFTER_UPDATE    INTEGER,
    @BEFORE_COMMIT   INTEGER,
	@NUNOTA			 INTEGER,
	@CODTIPOPER		 INT,
	@DHTIPOPER		 DATE,
	@CODEMPCAB		 INT,
	@CODPARC		 INT,
	@FRETEITE		 VARCHAR(10),
	@VLRFRETE		 NUMERIC(10, 2),
	@VLRFRETE_REG    NUMERIC(10, 2),
	@VLRFRETEATUAL	 NUMERIC(10, 2),
	@STATUSNOTA		 VARCHAR(1),
	@CODREG			 INT,
	@MENSAGEM		 VARCHAR(4000),
	@COUNT			 INT,
	@CODPARCTRANSP	 INT,
	@CODEMPNEGOC	 INT,
	@VLRDESCFRETE	 NUMERIC(10, 2),
	@VLRACRESCFRETE  NUMERIC(10, 2),
	@VLRDESTAQUE	 NUMERIC(10, 2),
	@VLREMB			 NUMERIC(10, 2),
	@VLRVENDOR		 NUMERIC(10, 2),
	@VLRTOTITENS	 NUMERIC(10, 2),
	@VLRNOTA		 NUMERIC(10, 2),
	@PERCDESC		 NUMERIC(10, 2),
	@VLRDESC         NUMERIC(10, 2),
	@AD_VLRDESCFRETE NUMERIC(12, 2),
	@P_DTENTREGA     DATETIME,
	@P_VLRFRETE      NUMERIC(10, 2),
	@P_VLRDESCFRETE  NUMERIC(10, 2)

BEGIN
	SET @BEFORE_INSERT = 0
    SET @AFTER_INSERT  = 1
    SET @BEFORE_DELETE = 2
    SET @AFTER_DELETE  = 3
    SET @BEFORE_UPDATE = 4
    SET @AFTER_UPDATE  = 5
	SET @BEFORE_COMMIT = 10
	
	-------------------------------------------------------------------------
	-- Objetivo: Calcular o Frete do pedido de acordo com o peso dos itens do pedido
	-------------------------------------------------------------------------
	SET @NUNOTA = sankhya.EVP_GET_CAMPO_INT(@P_IDSESSAO, 'NUNOTA')

	IF @P_TIPOEVENTO = @BEFORE_INSERT OR @P_TIPOEVENTO = @BEFORE_UPDATE
	BEGIN
		SET @CODTIPOPER = sankhya.EVP_GET_CAMPO_INT(@P_IDSESSAO, 'CODTIPOPER')
		SET @DHTIPOPER = sankhya.EVP_GET_CAMPO_DTA(@P_IDSESSAO, 'DHTIPOPER')
		SET @CODEMPCAB = sankhya.EVP_GET_CAMPO_INT(@P_IDSESSAO, 'CODEMP')
		SET @VLRFRETE = sankhya.EVP_GET_CAMPO_DEC(@P_IDSESSAO, 'VLRFRETE')
		SET @AD_VLRDESCFRETE = sankhya.EVP_GET_CAMPO_DEC(@P_IDSESSAO, 'AD_VLRDESCFRETE')
		SET @STATUSNOTA = sankhya.EVP_GET_CAMPO_TEXTO(@P_IDSESSAO, 'STATUSNOTA')

		SELECT
			@FRETEITE = ISNULL(TPO.AD_FRETEITE, 'N')
		FROM
			TGFTOP TPO (NOLOCK)
		WHERE
			TPO.CODTIPOPER = @CODTIPOPER
			AND CONVERT(DATE, TPO.DHALTER, 105) = CONVERT(DATE, @DHTIPOPER, 105);

		DECLARE
			@VLRFRETEORIG      NUMERIC(12, 2),
			@TIPFRETEORIG      VARCHAR(1),
			@CIF_FOBORIG       VARCHAR(1),
			@CODPARCTRANSPORIG INT

		IF @FRETEITE = 'C' AND @CODEMPCAB NOT IN (7, 9)
		BEGIN 
			SET @CODPARC = sankhya.EVP_GET_CAMPO_INT(@P_IDSESSAO, 'CODPARC')
			SET @CODREG = sankhya.EVP_GET_CAMPO_INT(@P_IDSESSAO, 'AD_CODREGENTREGA')

			IF @STATUSNOTA <> 'L'
			BEGIN
				IF ISNULL(@CODREG, 0) = 0
				BEGIN
					SET @MENSAGEM = 'Regi�o n�o definida para o endere�o de entrega. Cadastre uma regi�o na cidade de entrega, para efetuar o calculo de frete.'
					--EXEC SANKHYA.SNK_ERROR @MENSAGEM
				END
				ELSE
				BEGIN
					-- Verifica quantas s�o as datas de entrega / verifica se h� itens para entrega
					SELECT
						@COUNT = COUNT(1)
					FROM
						(
							SELECT
								DISTINCT
								ISNULL(AD_DTENTREGA, GETDATE()) AS DTENTREGA
							FROM
								TGFITE (NOLOCK)
							WHERE
								ISNULL(AD_ENTREGA, 'N') = 'E'
							   	AND NUNOTA = @NUNOTA
						) AS I;
					
					
					IF @COUNT > 0
					BEGIN
						-- Verifica o valor do frete da regi�o de entrega
						SELECT
							@VLRFRETE_REG = AD_VLRFRETE
						FROM
							TSIREG (NOLOCK)
						WHERE
							CODREG = @CODREG;
						
						
						IF @VLRFRETE_REG IS NULL
						BEGIN
							SET @MENSAGEM = 'Valor do frete n�o definido para a regi�o (' + CAST(@CODREG AS VARCHAR(15))+ '). Solicite o cadastro do frete para essa regi�o'
							EXEC SANKHYA.SNK_ERROR @MENSAGEM
						END
						ELSE
						BEGIN
							EXEC sankhya.EVP_SET_CAMPO_TEXTO @P_IDSESSAO, 'TIPFRETE', 'S'
							EXEC sankhya.EVP_SET_CAMPO_TEXTO @P_IDSESSAO, 'CIF_FOB', 'F'
							
							SET @CODPARCTRANSP = sankhya.EVP_GET_CAMPO_INT(@P_IDSESSAO, 'CODPARCTRANSP')
							SET @CODEMPNEGOC = sankhya.EVP_GET_CAMPO_INT(@P_IDSESSAO, 'CODEMPNEGOC')
							SET @CODPARCTRANSP = CASE
													WHEN @CODPARCTRANSP = 0 THEN ISNULL((
														SELECT
															E.AD_CODPARCTRANSP
														FROM
															TGFEMP (nolock) E
														WHERE
															E.CODEMP = @CODEMPNEGOC
													), 0)
													ELSE @CODPARCTRANSP
												END
							
												
							EXEC sankhya.EVP_SET_CAMPO_INT @P_IDSESSAO, 'CODPARCTRANSP', @CODPARCTRANSP
							
							
							SELECT
								@VLRFRETE = SUM(U.VLRFRETECALC)
							FROM
								(
									SELECT
										T.NROUNICO,
										T.DTENTREGA,
										SUM(T.PESOBRUTOCALC) AS PESOTOTALITENS,
										CASE
											WHEN SUM(T.PESOBRUTOCALC) <= 1000 THEN @VLRFRETE_REG
											WHEN SUM(T.PESOBRUTOCALC) > 1000 THEN ((SUM(T.PESOBRUTOCALC) - 1000) * 0.08) + @VLRFRETE_REG
										END AS VLRFRETECALC
									FROM
										(
											SELECT
												CAB.NUNOTA AS NROUNICO,
												ITE.SEQUENCIA AS SEQUENCIA,
												ITE.CODPROD AS CODPROD,
												ITE.QTDNEG AS QTDNEG,
												ITE.CODVOL,
												ITE.AD_ENTREGA AS ENTREGA,
												PRO.PESOBRUTO AS PESOBRUTO,
												PRO.PESOLIQ AS CADASTROPESO,
												ROUND(PRO.PESOBRUTO * ITE.QTDNEG, 2) AS PESOBRUTOCALC,
												ROUND(PRO.PESOLIQ * ITE.QTDNEG, 2) AS PESOLIQCALC,
												CAB.PESO AS PESOTOTALCAB,
												ITE.AD_DTENTREGA AS DTENTREGA
											FROM
												TGFCAB CAB
											INNER JOIN TGFITE ITE ON
												ITE.NUNOTA = CAB.NUNOTA
											INNER JOIN TGFPRO PRO ON
												PRO.CODPROD = ITE.CODPROD
											WHERE
												CAB.NUNOTA = @NUNOTA
												AND ITE.AD_ENTREGA = 'E'
										) AS T
									GROUP BY
										T.NROUNICO,
										T.DTENTREGA
								) AS U
							GROUP BY
								U.NROUNICO;
							
							
							EXEC sankhya.EVP_SET_CAMPO_DEC @P_IDSESSAO, 'VLRFRETECALC', @VLRFRETE
							
							
							SET @VLRDESCFRETE = sankhya.EVP_GET_CAMPO_DEC(@P_IDSESSAO, 'AD_VLRDESCFRETE')
							SET @VLRACRESCFRETE = ISNULL(sankhya.EVP_GET_CAMPO_DEC(@P_IDSESSAO, 'AD_VLRACRESCFRETE'), 0)
							SET @VLRFRETE = ROUND(ISNULL(@VLRFRETE, 0) - ISNULL(@VLRDESCFRETE, 0) + ISNULL(@VLRACRESCFRETE, 0), 2)
							
							
							IF @VLRFRETE <= 0
								SET @VLRFRETE = 0
							
							
							EXEC sankhya.EVP_SET_CAMPO_DEC @P_IDSESSAO, 'VLRFRETE', @VLRFRETE
							
							
							SELECT
								@VLRTOTITENS = SUM(ROUND(I.VLRTOT - I.VLRDESC + I.VLRSUBST + I.VLRIPI, 2))
							FROM
								TGFITE I (NOLOCK)
							WHERE
								I.NUNOTA = @NUNOTA;
		
							
							SET @VLRDESTAQUE = ISNULL(sankhya.EVP_GET_CAMPO_DEC(@P_IDSESSAO, 'VLRDESTAQUE'), 0)
							SET @VLREMB = ISNULL(sankhya.EVP_GET_CAMPO_DEC(@P_IDSESSAO, 'VLREMB'), 0)
							SET @VLRVENDOR = ISNULL(sankhya.EVP_GET_CAMPO_DEC(@P_IDSESSAO, 'VLRVENDOR'), 0)
		
							SET @VLRDESC = ISNULL(sankhya.EVP_GET_CAMPO_DEC(@P_IDSESSAO, 'VLRDESCTOT'), 0)
		
							SET @VLRNOTA = @VLRTOTITENS - ISNULL(@VLRDESC, 0) + @VLRFRETE + @VLRDESTAQUE + @VLREMB + @VLRVENDOR
							
							
							EXEC sankhya.EVP_SET_CAMPO_DEC @P_IDSESSAO, 'VLRNOTA', @VLRNOTA
		
							
							SET @VLRFRETEORIG = sankhya.EVP_GET_CAMPO_DEC(@P_IDSESSAO, 'VLRFRETE')
							SET @TIPFRETEORIG = sankhya.EVP_GET_CAMPO_TEXTO(@P_IDSESSAO, 'TIPFRETE')
							SET @CIF_FOBORIG  = sankhya.EVP_GET_CAMPO_TEXTO(@P_IDSESSAO, 'CIF_FOB')
							SET @CODPARCTRANSPORIG = sankhya.EVP_GET_CAMPO_INT(@P_IDSESSAO, 'CODPARCTRANSP')
		
							
							EXEC sankhya.EVP_SET_CAMPO_DEC @P_IDSESSAO, 'AD_VLRFRETE', @VLRFRETEORIG
							EXEC sankhya.EVP_SET_CAMPO_TEXTO @P_IDSESSAO, 'AD_TIPFRETE', @TIPFRETEORIG
							EXEC sankhya.EVP_SET_CAMPO_TEXTO @P_IDSESSAO, 'AD_CIF_FOB', @CIF_FOBORIG
							EXEC sankhya.EVP_SET_CAMPO_INT @P_IDSESSAO, 'AD_CODPARCTRANSP', @CODPARCTRANSPORIG
							
							
							-- Calcular o valor do frete total para cada data de entrega e atualiza a tgfite
							DECLARE cur_VLR_DATAS_DE_ENTREGA CURSOR
							FOR
								SELECT
									T.NROUNICO,
									(
										CASE
											WHEN SUM(T.PESOBRUTOCALC) <= 1000 THEN @VLRFRETE_REG
											WHEN SUM(T.PESOBRUTOCALC) > 1000 THEN ((SUM(T.PESOBRUTOCALC) - 1000) * 0.08) + @VLRFRETE_REG
										END
									) + ROUND(@VLRACRESCFRETE / @COUNT, 2) AS VLRFRETECALC,
									/* Desconto do frete tamb�m precisa ser distribu�do entre os produtos
									 * Dessa forma, o total do desconto dado � dividido pela quantidade de datas de entrega diferentes
									 * E posteriormente dividido entre os itens de cada uma das datas*/
									ROUND(@AD_VLRDESCFRETE / @COUNT, 2) AS VLRDESCFRETE,
									T.DTENTREGA
								FROM
									(
										SELECT
											CAB.NUNOTA AS NROUNICO,
											ITE.SEQUENCIA AS SEQUENCIA,
											ITE.CODPROD AS CODPROD,
											ITE.QTDNEG AS QTDNEG,
											ITE.CODVOL,
											ITE.AD_ENTREGA AS ENTREGA,
											PRO.PESOBRUTO AS PESOBRUTO,
											PRO.PESOLIQ AS CADASTROPESO,
											ROUND(PRO.PESOBRUTO * ITE.QTDNEG, 2) AS PESOBRUTOCALC,
											ROUND(PRO.PESOLIQ * ITE.QTDNEG, 2) AS PESOLIQCALC,
											CAB.PESO AS PESOTOTALCAB,
											ITE.AD_DTENTREGA AS DTENTREGA
										FROM
											TGFCAB CAB
										INNER JOIN TGFITE ITE ON
											ITE.NUNOTA = CAB.NUNOTA
										INNER JOIN TGFPRO PRO ON
											PRO.CODPROD = ITE.CODPROD
										WHERE
											CAB.NUNOTA = @NUNOTA
											AND ITE.AD_ENTREGA = 'E'
									) AS T
								GROUP BY
									T.NROUNICO,
									T.DTENTREGA;
							
							OPEN cur_VLR_DATAS_DE_ENTREGA
							FETCH NEXT FROM cur_VLR_DATAS_DE_ENTREGA INTO @NUNOTA, @P_VLRFRETE, @P_VLRDESCFRETE, @P_DTENTREGA
							
							WHILE @@FETCH_STATUS = 0
							BEGIN
								EXEC sankhya.DAL_STP_DISTRIBFRETEITENS_PESO @NUNOTA, @P_VLRFRETE, @P_VLRDESCFRETE, @P_DTENTREGA
		
								FETCH NEXT FROM cur_VLR_DATAS_DE_ENTREGA INTO @NUNOTA, @P_VLRFRETE, @P_VLRDESCFRETE, @P_DTENTREGA
							END
							CLOSE cur_VLR_DATAS_DE_ENTREGA
							DEALLOCATE cur_VLR_DATAS_DE_ENTREGA
							
							
							-- Se o valor do frete atual � maior que o frete calculado, mantem o valor do frete atual
							--SET @VLRFRETEATUAL = sankhya.EVP_GET_CAMPO_DEC(@P_IDSESSAO, 'VLRFRETE')
							EXEC sankhya.EVP_SET_CAMPO_DEC @P_IDSESSAO, 'VLRFRETE', @VLRFRETE
		
							
							SELECT
								@VLRTOTITENS = SUM(ROUND(I.VLRTOT - I.VLRDESC + I.VLRSUBST + I.VLRIPI, 2))
							FROM
								TGFITE I (NOLOCK)
						 	WHERE
								I.NUNOTA = @NUNOTA;
							
							
							SET @VLRDESTAQUE = ISNULL(sankhya.EVP_GET_CAMPO_DEC(@P_IDSESSAO, 'VLRDESTAQUE'),0)
							SET @VLREMB = ISNULL(sankhya.EVP_GET_CAMPO_DEC(@P_IDSESSAO, 'VLREMB'),0)
							SET @VLRVENDOR = ISNULL(sankhya.EVP_GET_CAMPO_DEC(@P_IDSESSAO, 'VLRVENDOR'),0)
							
							
							SET @VLRDESC = ISNULL(sankhya.EVP_GET_CAMPO_DEC(@P_IDSESSAO, 'VLRDESCTOT'),0)
		
							
							SET @VLRNOTA = @VLRTOTITENS - ISNULL(@VLRDESC,0) + @VLRFRETE + @VLRDESTAQUE + @VLREMB + @VLRVENDOR
							
							
							EXEC sankhya.EVP_SET_CAMPO_DEC @P_IDSESSAO, 'VLRNOTA', @VLRNOTA
							
							
							SET @VLRFRETEORIG = sankhya.EVP_GET_CAMPO_DEC(@P_IDSESSAO, 'VLRFRETE')
							SET @TIPFRETEORIG = sankhya.EVP_GET_CAMPO_TEXTO(@P_IDSESSAO, 'TIPFRETE')
							SET @CIF_FOBORIG  = sankhya.EVP_GET_CAMPO_TEXTO(@P_IDSESSAO, 'CIF_FOB')
							SET @CODPARCTRANSPORIG = sankhya.EVP_GET_CAMPO_INT(@P_IDSESSAO, 'CODPARCTRANSP')
							
							
							EXEC sankhya.EVP_SET_CAMPO_DEC @P_IDSESSAO, 'AD_VLRFRETE', @VLRFRETEORIG
							EXEC sankhya.EVP_SET_CAMPO_TEXTO @P_IDSESSAO, 'AD_TIPFRETE', @TIPFRETEORIG
							EXEC sankhya.EVP_SET_CAMPO_TEXTO @P_IDSESSAO, 'AD_CIF_FOB', @CIF_FOBORIG
							EXEC sankhya.EVP_SET_CAMPO_INT @P_IDSESSAO, 'AD_CODPARCTRANSP', @CODPARCTRANSPORIG
							
						END
					END
					ELSE
					BEGIN
						EXEC sankhya.EVP_SET_CAMPO_DEC @P_IDSESSAO, 'VLRFRETE', 0
						EXEC sankhya.EVP_SET_CAMPO_DEC @P_IDSESSAO, 'VLRFRETECALC', 0
						EXEC sankhya.EVP_SET_CAMPO_DEC @P_IDSESSAO, 'AD_VLRDESCFRETE', 0
						EXEC sankhya.EVP_SET_CAMPO_TEXTO @P_IDSESSAO, 'TIPFRETE', 'N'
						EXEC sankhya.EVP_SET_CAMPO_TEXTO @P_IDSESSAO, 'CIF_FOB', 'S'
						EXEC sankhya.EVP_SET_CAMPO_INT @P_IDSESSAO, 'CODPARCTRANSP', 0
						
						SET @VLRFRETEORIG = sankhya.EVP_GET_CAMPO_DEC(@P_IDSESSAO, 'VLRFRETE')
						SET @TIPFRETEORIG = sankhya.EVP_GET_CAMPO_TEXTO(@P_IDSESSAO, 'TIPFRETE')
						SET @CIF_FOBORIG  = sankhya.EVP_GET_CAMPO_TEXTO(@P_IDSESSAO, 'CIF_FOB')
						SET @CODPARCTRANSPORIG = sankhya.EVP_GET_CAMPO_INT(@P_IDSESSAO, 'CODPARCTRANSP')
						
						EXEC sankhya.EVP_SET_CAMPO_DEC @P_IDSESSAO, 'AD_VLRFRETE', @VLRFRETEORIG
						EXEC sankhya.EVP_SET_CAMPO_TEXTO @P_IDSESSAO, 'AD_TIPFRETE', @TIPFRETEORIG
						EXEC sankhya.EVP_SET_CAMPO_TEXTO @P_IDSESSAO, 'AD_CIF_FOB', @CIF_FOBORIG
						EXEC sankhya.EVP_SET_CAMPO_INT @P_IDSESSAO, 'AD_CODPARCTRANSP', @CODPARCTRANSPORIG
			
						UPDATE
							TGFITE
						SET
							AD_VLRFRETE = 0,
							AD_VLRDESCFRETE = 0
						WHERE
							NUNOTA = @NUNOTA
						   	AND ISNULL(AD_ENTREGA, 'N') <> 'E';
						   
					END
				END
			END
			ELSE
			BEGIN
				SET @CODREG = sankhya.EVP_GET_CAMPO_INT(@P_IDSESSAO, 'AD_CODREGENTREGA')
				IF ISNULL(@CODREG,0) = 0
				BEGIN
					SET @MENSAGEM = 'Regi�o n�o definida para o endere�o de entrega. Cadastre uma regi�o na cidade de entrega, para efetuar o calculo de frete.'
					EXEC SANKHYA.SNK_ERROR @MENSAGEM
				END

				SELECT @VLRTOTITENS = SUM(ROUND(I.VLRTOT - I.VLRDESC + I.VLRSUBST + I.VLRIPI, 2) )
				  FROM TGFITE I
				 WHERE I.NUNOTA = @NUNOTA
							
				IF ISNULL(@VLRTOTITENS,0) > 0
					EXEC sankhya.ESU_STP_DISTRIBFRETEITENS @NUNOTA, @VLRFRETE, @VLRDESCFRETE
				ELSE
					UPDATE TGFITE SET
						AD_VLRFRETE = 0,
						AD_VLRDESCFRETE = 0
					 WHERE NUNOTA = @NUNOTA
						AND ISNULL(AD_ENTREGA,'N') <> 'E'
			END
		END

		IF @FRETEITE = 'C' AND @STATUSNOTA <> 'L' AND @CODEMPCAB IN (7, 9)
		BEGIN
			--Preserva o valor calculado no e-commerce em campos adicionais, para ser utilizado nos movimentos seguintes
			SET @VLRFRETEORIG = sankhya.EVP_GET_CAMPO_DEC(@P_IDSESSAO, 'VLRFRETE')
			SET @TIPFRETEORIG = sankhya.EVP_GET_CAMPO_TEXTO(@P_IDSESSAO, 'TIPFRETE')
			SET @CIF_FOBORIG  = sankhya.EVP_GET_CAMPO_TEXTO(@P_IDSESSAO, 'CIF_FOB')
			SET @CODPARCTRANSPORIG = sankhya.EVP_GET_CAMPO_INT(@P_IDSESSAO, 'CODPARCTRANSP')
			
			EXEC sankhya.EVP_SET_CAMPO_DEC @P_IDSESSAO, 'AD_VLRFRETE', @VLRFRETEORIG
			EXEC sankhya.EVP_SET_CAMPO_TEXTO @P_IDSESSAO, 'AD_TIPFRETE', @TIPFRETEORIG
			EXEC sankhya.EVP_SET_CAMPO_TEXTO @P_IDSESSAO, 'AD_CIF_FOB', @CIF_FOBORIG
			EXEC sankhya.EVP_SET_CAMPO_INT @P_IDSESSAO, 'AD_CODPARCTRANSP', @CODPARCTRANSPORIG
		END

		IF @STATUSNOTA <> 'L'
		BEGIN
			--SE A TOP ESTIVER CONFIGURADA PARA
			--SOMAR O VALOR DO FRETE DISTRIBUIDO DOS ITENS
			IF @FRETEITE = 'S' AND @CODEMPCAB NOT IN (7, 9)
			BEGIN
				SET @CODPARCTRANSP = sankhya.EVP_GET_CAMPO_INT(@P_IDSESSAO, 'CODPARCTRANSP')
				SET @CODEMPNEGOC = sankhya.EVP_GET_CAMPO_INT(@P_IDSESSAO, 'CODEMPNEGOC')
				SET @CODPARCTRANSP = CASE WHEN @CODPARCTRANSP = 0 
											THEN ISNULL((SELECT E.AD_CODPARCTRANSP FROM TGFEMP E (NOLOCK) WHERE E.CODEMP = @CODEMPNEGOC),0)
											ELSE @CODPARCTRANSP
										END
				EXEC sankhya.EVP_SET_CAMPO_INT @P_IDSESSAO, 'CODPARCTRANSP', @CODPARCTRANSP

				SELECT @VLRTOTITENS = SUM(ROUND(I.VLRTOT - I.VLRDESC + I.VLRSUBST + I.VLRIPI,2)),
					   @VLRFRETE = SUM(CASE WHEN I.AD_ENTREGA = 'E' THEN ROUND(ISNULL(I.AD_VLRFRETE,0),2) ELSE 0 END),
					   @VLRDESCFRETE = SUM(CASE WHEN I.AD_ENTREGA = 'E' THEN ROUND(ISNULL(I.AD_VLRDESCFRETE,0),2) ELSE 0 END)
				  FROM TGFITE I (NOLOCK)
				 WHERE I.NUNOTA = @NUNOTA

				--SET @VLRDESCFRETE = ISNULL(sankhya.EVP_GET_CAMPO_DEC(@P_IDSESSAO, 'AD_VLRDESCFRETE'),0) -- n�o estava comentado
				SET @VLRFRETE = @VLRFRETE - ISNULL(@VLRDESCFRETE, 0) -- @VLRDESCFRETE estava comentado
				 
				IF @VLRFRETE <= 0
					SET @VLRFRETE = 0

				EXEC sankhya.EVP_SET_CAMPO_DEC @P_IDSESSAO, 'VLRFRETECALC', @VLRFRETE
				EXEC sankhya.EVP_SET_CAMPO_DEC @P_IDSESSAO, 'VLRFRETE', @VLRFRETE
				EXEC sankhya.EVP_SET_CAMPO_DEC @P_IDSESSAO, 'AD_VLRDESCFRETE', 0 --@VLRDESCFRETE
				EXEC sankhya.EVP_SET_CAMPO_TEXTO @P_IDSESSAO, 'TIPFRETE', 'S'
				EXEC sankhya.EVP_SET_CAMPO_TEXTO @P_IDSESSAO, 'CIF_FOB', 'F'
				
				SET @VLRDESTAQUE = ISNULL(sankhya.EVP_GET_CAMPO_DEC(@P_IDSESSAO, 'VLRDESTAQUE'),0)
				SET @VLREMB = ISNULL(sankhya.EVP_GET_CAMPO_DEC(@P_IDSESSAO, 'VLREMB'),0)
				SET @VLRVENDOR = ISNULL(sankhya.EVP_GET_CAMPO_DEC(@P_IDSESSAO, 'VLRVENDOR'),0)

				SET @PERCDESC = sankhya.EVP_GET_CAMPO_DEC(@P_IDSESSAO, 'PERCDESC')
				--SET @VLRDESC = ROUND(@VLRTOTITENS * ISNULL(@PERCDESC,0) / 100,2)
				SET @VLRDESC = ISNULL(sankhya.EVP_GET_CAMPO_DEC(@P_IDSESSAO, 'VLRDESCTOT'),0)

				SET @VLRNOTA = @VLRTOTITENS - ISNULL(@VLRDESC,0) + @VLRFRETE + @VLRDESTAQUE + @VLREMB + @VLRVENDOR
				EXEC sankhya.EVP_SET_CAMPO_DEC @P_IDSESSAO, 'VLRNOTA', @VLRNOTA
			END
			ELSE
			IF @FRETEITE = 'S' AND @CODEMPCAB IN (7, 9)
			BEGIN
				SET @VLRFRETEORIG = sankhya.EVP_GET_CAMPO_DEC(@P_IDSESSAO, 'AD_VLRFRETE')
				SET @TIPFRETEORIG = sankhya.EVP_GET_CAMPO_TEXTO(@P_IDSESSAO, 'AD_TIPFRETE')
				SET @CIF_FOBORIG  = sankhya.EVP_GET_CAMPO_TEXTO(@P_IDSESSAO, 'AD_CIF_FOB')
				SET @CODPARCTRANSPORIG = sankhya.EVP_GET_CAMPO_INT(@P_IDSESSAO, 'AD_CODPARCTRANSP')
			
				EXEC sankhya.EVP_SET_CAMPO_DEC @P_IDSESSAO, 'VLRFRETE', @VLRFRETEORIG
				EXEC sankhya.EVP_SET_CAMPO_TEXTO @P_IDSESSAO, 'TIPFRETE', @TIPFRETEORIG
				EXEC sankhya.EVP_SET_CAMPO_TEXTO @P_IDSESSAO, 'CIF_FOB', @CIF_FOBORIG
				EXEC sankhya.EVP_SET_CAMPO_INT @P_IDSESSAO, 'CODPARCTRANSP', @CODPARCTRANSPORIG
			END

			--SE A TOP ESTIVER CONFIGURADA PARA
			--ZERAR O VALOR DO FRETE NA NOTA
			IF @FRETEITE = 'Z' --AND @CODEMPCAB NOT IN (7, 9)
			BEGIN
				EXEC sankhya.EVP_SET_CAMPO_DEC @P_IDSESSAO, 'VLRFRETE', 0
				EXEC sankhya.EVP_SET_CAMPO_DEC @P_IDSESSAO, 'VLRFRETECALC', 0
				EXEC sankhya.EVP_SET_CAMPO_DEC @P_IDSESSAO, 'AD_VLRDESCFRETE', 0
				EXEC sankhya.EVP_SET_CAMPO_TEXTO @P_IDSESSAO, 'TIPFRETE', 'N'
				EXEC sankhya.EVP_SET_CAMPO_TEXTO @P_IDSESSAO, 'CIF_FOB', 'S'
				EXEC sankhya.EVP_SET_CAMPO_INT @P_IDSESSAO, 'CODPARCTRANSP', 0
			END

			IF @FRETEITE = 'N' AND @CODEMPCAB IN (7, 9)
			BEGIN
				SET @VLRFRETEORIG = sankhya.EVP_GET_CAMPO_DEC(@P_IDSESSAO, 'VLRFRETE')
				SET @TIPFRETEORIG = sankhya.EVP_GET_CAMPO_TEXTO(@P_IDSESSAO, 'TIPFRETE')
				SET @CIF_FOBORIG  = sankhya.EVP_GET_CAMPO_TEXTO(@P_IDSESSAO, 'CIF_FOB')
				SET @CODPARCTRANSPORIG = sankhya.EVP_GET_CAMPO_INT(@P_IDSESSAO, 'CODPARCTRANSP')
			
				EXEC sankhya.EVP_SET_CAMPO_DEC @P_IDSESSAO, 'AD_VLRFRETE', @VLRFRETEORIG
				EXEC sankhya.EVP_SET_CAMPO_TEXTO @P_IDSESSAO, 'AD_TIPFRETE', @TIPFRETEORIG
				EXEC sankhya.EVP_SET_CAMPO_TEXTO @P_IDSESSAO, 'AD_CIF_FOB', @CIF_FOBORIG
				EXEC sankhya.EVP_SET_CAMPO_INT @P_IDSESSAO, 'AD_CODPARCTRANSP', @CODPARCTRANSPORIG
			END

			IF @FRETEITE = 'O'
			BEGIN
				SET @VLRFRETEORIG = sankhya.EVP_GET_CAMPO_DEC(@P_IDSESSAO, 'AD_VLRFRETE')
				--SET @AD_VLRDESCFRETE = sankhya.EVP_GET_CAMPO_DEC(@P_IDSESSAO, 'AD_VLRDESCFRETE')
				SET @TIPFRETEORIG = sankhya.EVP_GET_CAMPO_TEXTO(@P_IDSESSAO, 'AD_TIPFRETE')
				SET @CIF_FOBORIG  = sankhya.EVP_GET_CAMPO_TEXTO(@P_IDSESSAO, 'AD_CIF_FOB')
				SET @CODPARCTRANSPORIG = sankhya.EVP_GET_CAMPO_INT(@P_IDSESSAO, 'AD_CODPARCTRANSP')
				
				EXEC sankhya.EVP_SET_CAMPO_DEC @P_IDSESSAO, 'VLRFRETE', @VLRFRETEORIG
				--EXEC sankhya.EVP_SET_CAMPO_DEC @P_IDSESSAO, 'AD_VLRDESCFRETE', @AD_VLRDESCFRETE
				EXEC sankhya.EVP_SET_CAMPO_TEXTO @P_IDSESSAO, 'TIPFRETE', @TIPFRETEORIG
				EXEC sankhya.EVP_SET_CAMPO_TEXTO @P_IDSESSAO, 'CIF_FOB', @CIF_FOBORIG
				EXEC sankhya.EVP_SET_CAMPO_INT @P_IDSESSAO, 'CODPARCTRANSP', @CODPARCTRANSPORIG
				
			END
			
		END
	END

END;