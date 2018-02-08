-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------MODELO FUGA CONSULTORA-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--CLOUD

---BD
use BD_ANALITICO
GO

-------------------------------------------------------DEFINICION TARGET----------------------------------------------------------


IF OBJECT_ID('KR_MATRIZ_TARG') IS NOT NULL
DROP PROCEDURE KR_MATRIZ_TARG
GO

CREATE PROCEDURE KR_MATRIZ_TARG
@CodPais CHAR(2),
@AnioCampana CHAR(6)

AS
BEGIN

/*
EXEC KR_MATRIZ_TARG 'CO','201716'
*/

 -------------------- Variables de Informacion de Campañas ------------------

---31/07--C-11 (Cerrado)
-- @AnioCampana        CHAR(6),--Cx--Campaña a Predecir
-- @AnioCampanamenos1  CHAR(6),--Cx-1
-- @AnioCampanamenos2  CHAR(6),--Cx-2--Campaña cierre de Data
--declare @AnioCampana  char(6),
-- 		  @CodPais CHAR(2)
--set @CodPais = 'CO'
--set @AnioCampana  = '201709'

declare @AnioCampanamenos1 CHAR(6),
	    @AnioCampanamenos2 CHAR(6)

set @AnioCampanamenos1 = dbo.CalculaAnioCampana(@AnioCampana, -1)
set @AnioCampanamenos2 = dbo.CalculaAnioCampana(@AnioCampana, -2)


-------------Datos PKebelista
--select * from [DWH_ANALITICO].[dbo].[DWH_FSTAEBECAM] where codstatus=6

IF OBJECT_ID('tempdb.dbo.##KR_MCC_TARGET', 'U') IS NOT NULL
  DROP TABLE ##KR_MCC_TARGET;

SELECT
@AnioCampana AS AnioCampanaT,
@AnioCampanamenos1 AS AnioCampana_Desfase,
@AnioCampanamenos2 AS AnioCampanaUC,
@CodPais AS CodPais,
A.PKEbelista,
C.PKTerritorio
--A.CodEbelista--,
--A.FlagGerenteZona
INTO ##KR_MCC_TARGET
FROM 
[DWH_ANALITICO].[dbo].[DWH_DEBELISTA]  A
INNER JOIN [DWH_ANALITICO].[dbo].[DWH_FSTAEBECAM] C ON A.PKEbelista = C.PKEbelista AND C.AnioCampana=@AnioCampana AND C.AnioCampana IS NOT NULL  AND C.CODPAIS=@CodPais 
INNER JOIN [DWH_ANALITICO].[dbo].[DWH_DSTATUS] D on C.CodStatus =D.CodStatus AND D.CODPAIS=@CodPais AND D.DesStatusCorp IN ('INGRESO','NORMALES','REINGRESO','EGRESADA')
WHERE A.AnioCampanaIngreso<>'0' AND  A.AnioCampanaIngreso<>' ' AND A.AnioCampanaIngreso IS NOT NULL AND A.AnioCampanaPrimerPedido IS NOT NULL AND A.AnioCampanaIngreso<=@AnioCampanamenos2  
AND  A.CODPAIS=@CodPais
;
--183969
--SELECT * FROM ##KR_MCC_TARGET
--SELECT count(*),count(distinct pkebelista) FROM ##KR_MCC_TARGET
--SELECT * FROM [DWH_ANALITICO].[dbo].[DWH_DSTATUS] 


---Activas + Egresos Campaña x+2
IF OBJECT_ID('tempdb.dbo.##KR_MCC_TARGET1', 'U') IS NOT NULL
  DROP TABLE ##KR_MCC_TARGET1;

SELECT
A.*,B.DESREGION,B.CODREGION,B.CODZONA,B.CODSECCION,
CASE WHEN B.Desregion IN ('OFICINA','00 ADMINISTRATIVO','EMPLEADOS') THEN 1 ELSE 0 END AS FlagBelcorp,CASE WHEN B.Desregion IN ('99 FONO TIENDA','AREA ELIMINADA CON ESTADISTICA','<SIN DESCRIPCION>','SIN HOMOLOGAR','CASTIGADAS','JUBILADOS Y MAQUILLADORES','ATENCION PREFERENCIAL') THEN 1 ELSE 0 END AS Flaginusual
INTO ##KR_MCC_TARGET1
FROM
##KR_MCC_TARGET A
INNER JOIN [DWH_ANALITICO].[dbo].[DWH_DGEOGRAFIACAMPANA] B ON A.PKTerritorio = B.PKTerritorio AND A.AnioCampanaT = B.AnioCampana AND A.CodPais=B.CodPais
;

--SELECT count(*),count(distinct pkebelista) FROM ##KR_MCC_TARGET1
--select B.DESREGION,count(1) tot from [DWH_ANALITICO].[dbo].[DWH_DGEOGRAFIACAMPANA] B where codpais='co'group by desregion order by tot desc
--select * from ##KR_MCC_TARGET1 where FlagBelcorp=1 or Flaginusual=1
--select distinct DESREGION from ##KR_MCC_TARGET1
--select * from ##KR_MCC_TARGET1 where Desregion='ATENCION PREFERENCIAL'

------------Comportamiento Rolling + IP unico zona
--SELECT * FROM [DWH_ANALITICO].[dbo].[DWH_DGEOGRAFIACAMPANA]
--SELECT * FROM ##KR_MCC_TARGET
--SELECT MIN(AnioCampana),MAX(AnioCampana) FROM  [DWH_ANALITICO].[dbo].[DWH_FSTAEBECAM]--C01
--201607	201802
--SELECT * FROM ##KR_MCC_TARGET1
--SELECT * FROM DSTATUS
--SELECT * FROM DCOMPORTAMIENTOROLLING

IF OBJECT_ID('tempdb.dbo.##KR_MCC_COMPT', 'U') IS NOT NULL
  DROP TABLE ##KR_MCC_COMPT;

SELECT C.PKebelista,C.AnioCampana,C.flagactiva,C.FlagPasoPedido,D.DesNivelComportamiento,E.DesStatusCorp
into ##KR_MCC_COMPT
from 
##KR_MCC_TARGET1 A
INNER JOIN [DWH_ANALITICO].[dbo].[DWH_FSTAEBECAM] C ON ltrim(rtrim(A.PKEBELISTA)) = ltrim(rtrim(C.PKEbelista)) and ltrim(rtrim(C.AnioCampana))<=ltrim(rtrim(@AnioCampana))  and ltrim(rtrim(C.AnioCampana)) >=ltrim(rtrim(@AnioCampanamenos2)) AND C.CODPAIS=@CodPais   
INNER JOIN [DWH_ANALITICO].[dbo].[DWH_DCOMPORTAMIENTOROLLING] D on ltrim(rtrim(C.codcomportamientorolling)) =ltrim(rtrim(D.CodComportamiento)) 
INNER JOIN [DWH_ANALITICO].[dbo].[DWH_DSTATUS] E on C.CodStatus =E.CodStatus AND E.CODPAIS=@CodPais   
group by C.PKebelista,C.AnioCampana,C.flagactiva,C.FlagPasoPedido,D.DesNivelComportamiento,E.DesStatusCorp
;
---(19715 row(s) affected)


--select * from [DWH_ANALITICO].[dbo].[DWH_DCOMPORTAMIENTOROLLING]
--select * from [DWH_ANALITICO].[dbo].[DWH_FSTAEBECAM] WHERE PKEBELISTA=1831725 and codpais='CO' ORDER BY ANIOCAMPANA
--select * from ##KR_MCC_COMPT WHERE PKEBELISTA=1831725 ORDER BY ANIOCAMPANA
--select * from  [DWH_ANALITICO].[dbo].[DWH_DSTATUS] where CODPAIS='co'
--select min(AnioCampana),max(AnioCampana) from ##KR_MCC_COMPT
--select distinct  AnioCampana from #KR_MCC_COMP order by 1
--select AnioCampana,count(1) from ##KR_MCC_COMPT group by AnioCampana


--select * from ##KR_MCC_COMPT where PKebelista=48023 order by  AnioCampana
--go

--select * from ##KR_CONSTANCIA1 where PKebelista=48023 --order by  AnioCampana
--go

--select * from [DWH_ANALITICO].[dbo].[DWH_DCOMPORTAMIENTOROLLING] 



----------------------COMPORTAMIENTO ROLLING

IF OBJECT_ID('tempdb.dbo.##KR_COMP_ROLLINGT', 'U') IS NOT NULL
  DROP TABLE ##KR_COMP_ROLLINGT;

DECLARE @SQLString2 NVARCHAR(2000);

SET @SQLString2 = 
N'
SELECT PKebelista,['+ @AnioCampanamenos2+ '] AS Cx_Comp_Rolling,['+ @AnioCampanamenos1+ '] AS Cx1_Comp_Rolling,['+ @AnioCampana + '] AS Cx2_Comp_Rolling 
INTO ##KR_COMP_ROLLINGT
FROM 
(SELECT PKebelista,Aniocampana,DesNivelComportamiento from ##KR_MCC_COMPT ) as SourceTable 
PIVOT 
(COUNT(DesNivelComportamiento)
 FOR Aniocampana in (['+@AnioCampanamenos2+'],['+@AnioCampanamenos1+'],['+@AnioCampana+'])) AS PivotTable;'

EXEC sp_executesql @SQLString2;

---4945

--SELECT * FROM ##KR_COMP_ROLLING
--SELECT * FROM ##KR_COMP_ROLLING WHERE [C0_Comp_Rolling]>1 or [C1_Comp_Rolling]>1 or [C2_Comp_Rolling]>1 or [C3_Comp_Rolling]>1 or [C4_Comp_Rolling]>1 or [C5_Comp_Rolling]>1 or [C6_Comp_Rolling]>1


IF OBJECT_ID('tempdb.dbo.##KR_COMP_ROLLINGT1', 'U') IS NOT NULL
  DROP TABLE ##KR_COMP_ROLLINGT1;

select pkebelista,
(select DesNivelComportamiento from ##KR_MCC_COMPT a where a.PKEbelista=b.pkebelista and AnioCampana=@AnioCampanamenos2) Cx_Comp_Rolling,
(select DesNivelComportamiento from ##KR_MCC_COMPT a where a.PKEbelista=b.pkebelista and AnioCampana=@AnioCampanamenos1) Cx1_Comp_Rolling,
(select DesNivelComportamiento from ##KR_MCC_COMPT a where a.PKEbelista=b.pkebelista and AnioCampana=@AnioCampana) Cx2_Comp_Rolling
into ##KR_COMP_ROLLINGT1
from ##KR_COMP_ROLLINGT b 
group by pkebelista;
---4945 

--select * from ##KR_MCC_COMPT where PKebelista=2882009 order by  AnioCampana
--go

--select * from ##KR_COMP_ROLLINGT1 where PKebelista=2882009 --order by  AnioCampana
--go

----------------------COD STATUS

IF OBJECT_ID('tempdb.dbo.##KR_COD_STATUST', 'U') IS NOT NULL
  DROP TABLE ##KR_COD_STATUST;

DECLARE @SQLString3 NVARCHAR(2000);

SET @SQLString3 = 
N'
SELECT PKebelista,['+ @AnioCampanamenos2+ '] AS Cx_Cod_Status,['+ @AnioCampanamenos1+ '] AS Cx1_Cod_Status,['+ @AnioCampana + '] AS Cx2_Cod_Status 
INTO ##KR_COD_STATUST
FROM 
(SELECT PKebelista,Aniocampana,DesStatusCorp from ##KR_MCC_COMPT ) as SourceTable 
PIVOT 
(COUNT(DesStatusCorp)
 FOR Aniocampana in (['+@AnioCampanamenos2+'],['+@AnioCampanamenos1+'],['+@AnioCampana+'])) AS PivotTable;'

EXEC sp_executesql @SQLString3;

---4945


IF OBJECT_ID('tempdb.dbo.##KR_COD_STATUST1', 'U') IS NOT NULL
  DROP TABLE ##KR_COD_STATUST1;

select pkebelista,
(select DesStatusCorp from ##KR_MCC_COMPT a where a.PKEbelista=b.pkebelista and AnioCampana=@AnioCampanamenos2) Cx_Status,
(select DesStatusCorp from ##KR_MCC_COMPT a where a.PKEbelista=b.pkebelista and AnioCampana=@AnioCampanamenos1) Cx1_Status,
(select DesStatusCorp from ##KR_MCC_COMPT a where a.PKEbelista=b.pkebelista and AnioCampana=@AnioCampana)  Cx2_Status
into ##KR_COD_STATUST1
from ##KR_COD_STATUST b 
group by pkebelista;
---4945 

--select * from ##KR_MCC_COMPT where PKebelista=2882009 order by  AnioCampana
--go

--select * from ##KR_COD_STATUST1 where PKebelista=2882009 --order by  AnioCampana
--go



---------------------FLAG PASO PEDIDO

IF OBJECT_ID('tempdb.dbo.##FLAGPASOPEDIDOT', 'U') IS NOT NULL
  DROP TABLE ##FLAGPASOPEDIDOT;

DECLARE @SQLString5 NVARCHAR(2000);

SET @SQLString5 = 
N'
SELECT PKebelista,['+ @AnioCampanamenos2+ '] AS Cx_FlagPasoPedido,['+ @AnioCampanamenos1+ '] AS Cx1_FlagPasoPedido,['+ @AnioCampana + '] AS Cx2_FlagPasoPedido 
INTO ##FLAGPASOPEDIDOT
FROM 
(SELECT PKebelista,Aniocampana,FlagPasoPedido from ##KR_MCC_COMPT ) as SourceTable 
PIVOT 
(COUNT(FlagPasoPedido)
 FOR Aniocampana in (['+@AnioCampanamenos2+'],['+@AnioCampanamenos1+'],['+@AnioCampana+'])) AS PivotTable;'

EXEC sp_executesql @SQLString5;

--SELECT * FROM ##FLAGPASOPEDIDO
--SELECT * FROM ##FLAGPASOPEDIDO WHERE [C0_FLAGPASOPEDIDO]>1 or[C1_FLAGPASOPEDIDO]>1 or [C2_FLAGPASOPEDIDO]>1 or [C3_FLAGPASOPEDIDO]>1 or [C4_FLAGPASOPEDIDO]>1 or [C5_FLAGPASOPEDIDO]>1 or [C6_FLAGPASOPEDIDO]>1

IF OBJECT_ID('tempdb.dbo.##FLAGPASOPEDIDOT1', 'U') IS NOT NULL
  DROP TABLE ##FLAGPASOPEDIDOT1;

select pkebelista,
(select FlagPasoPedido from ##KR_MCC_COMPT a where a.PKEbelista=b.pkebelista and AnioCampana=@AnioCampanamenos2) Cx_PasoPedido,
(select FlagPasoPedido from ##KR_MCC_COMPT a where a.PKEbelista=b.pkebelista and AnioCampana=@AnioCampanamenos1) Cx1_PasoPedido,
(select FlagPasoPedido from ##KR_MCC_COMPT a where a.PKEbelista=b.pkebelista and AnioCampana=@AnioCampana) Cx2_PasoPedido
into ##FLAGPASOPEDIDOT1
from ##FLAGPASOPEDIDOT b 
group by pkebelista;
---4945 
--select * from ##KR_MCC_COMPT where PKebelista=2882009 order by  AnioCampana
--go

--select * from ##FLAGPASOPEDIDOT1 where PKebelista=2882009 --order by  AnioCampana
--go

---------------------FLAG ACTIVO

IF OBJECT_ID('tempdb.dbo.##FLAG_ACTIVOT', 'U') IS NOT NULL
  DROP TABLE ##FLAG_ACTIVOT;

DECLARE @SQLString6 NVARCHAR(2000);

SET @SQLString6 = 
N'
SELECT PKebelista,['+ @AnioCampanamenos2+ '] AS Cx_flagactiva,['+ @AnioCampanamenos1+ '] AS Cx1_flagactiva,['+ @AnioCampana + '] AS Cx2_flagactiva 
INTO ##FLAG_ACTIVOT
FROM 
(SELECT PKebelista,Aniocampana,flagactiva from ##KR_MCC_COMPT ) as SourceTable 
PIVOT 
(COUNT(flagactiva)
 FOR Aniocampana in (['+@AnioCampanamenos2+'],['+@AnioCampanamenos1+'],['+@AnioCampana+'])) AS PivotTable;'

EXEC sp_executesql @SQLString6;

--SELECT * FROM ##FLAGACTIVO
--SELECT * FROM ##FLAGACTIVO WHERE [C0_FLAGPASOPEDIDO]>1 or[C1_FLAGPASOPEDIDO]>1 or [C2_FLAGPASOPEDIDO]>1 or [C3_FLAGPASOPEDIDO]>1 or [C4_FLAGPASOPEDIDO]>1 or [C5_FLAGPASOPEDIDO]>1 or [C6_FLAGPASOPEDIDO]>1

IF OBJECT_ID('tempdb.dbo.##FLAG_ACTIVOT1', 'U') IS NOT NULL
  DROP TABLE ##FLAG_ACTIVOT1;

select pkebelista,
(select flagactiva from ##KR_MCC_COMPT a where a.PKEbelista=b.pkebelista and AnioCampana=@AnioCampanamenos2) Cx_Activa,
(select flagactiva from ##KR_MCC_COMPT a where a.PKEbelista=b.pkebelista and AnioCampana=@AnioCampanamenos1) Cx1_Activa,
(select flagactiva from ##KR_MCC_COMPT a where a.PKEbelista=b.pkebelista and AnioCampana=@AnioCampana) Cx2_Activa
into ##FLAG_ACTIVOT1
from ##FLAG_ACTIVOT b 
group by pkebelista;
---4945 

--select * from ##KR_MCC_COMPT where PKebelista=2882009 order by  AnioCampana
--go

--select * from ##FLAG_ACTIVOT1 where PKebelista=2882009 --order by  AnioCampana
--go

--------------------TABLA FINAL:

IF OBJECT_ID('tempdb.dbo.##KR_MCC_TARGET2', 'U') IS NOT NULL
  DROP TABLE ##KR_MCC_TARGET2;

SELECT
A.*,
C.Cx_Status,
C.Cx1_Status,
C.Cx2_Status,
G.Cx_Activa,
G.Cx1_Activa,
G.Cx2_Activa,
E.Cx_Comp_Rolling,
E.Cx1_Comp_Rolling,
E.Cx2_Comp_Rolling,
F.Cx_PasoPedido,
F.Cx1_PasoPedido,
F.Cx2_PasoPedido
INTO ##KR_MCC_TARGET2
FROM 
##KR_MCC_TARGET1 A
LEFT JOIN ##KR_COD_STATUST1 C   ON A.PKEbelista=C.PKEbelista
LEFT JOIN ##KR_COMP_ROLLINGT1 E ON A.PKEbelista=E.PKEbelista
LEFT JOIN ##FLAGPASOPEDIDOT1 F ON A.PKEbelista=F.PKEbelista
LEFT JOIN ##FLAG_ACTIVOT1 G ON A.PKEbelista=G.PKEbelista;

-- SELECT * FROM ##KR_MCC_DATOS2
-- SELECT COUNT(1),COUNT(DISTINCT PKEbelista) FROM ##KR_MCC_DATOS2
-- 63,357	63,357

DECLARE @SQLString7 NVARCHAR(2000);

SET @SQLString7 = 
N'
IF OBJECT_ID(''tempdb.dbo.##KR_MCC_TARGET_'+@AnioCampana+' '', ''U'') IS NOT NULL
DROP TABLE ##KR_MCC_TARGET_'+@AnioCampana;

EXEC sp_executesql @SQLString7;


DECLARE @SQLString8 NVARCHAR(2000);

SET @SQLString8 = 
N'
SELECT * INTO ##KR_MCC_TARGET_'+@AnioCampana+' FROM ##KR_MCC_TARGET2'

EXEC sp_executesql @SQLString8;

END

GO

--EXEC dbo.KR_MATRIZ_TARG 'PE','201712'
--EXEC dbo.KR_MATRIZ_TARG 'PE','201713'
--EXEC dbo.KR_MATRIZ_TARG 'PE','201714'
--EXEC dbo.KR_MATRIZ_TARG 'PE','201715'
EXEC dbo.KR_MATRIZ_TARG 'PE','201716'
EXEC dbo.KR_MATRIZ_TARG 'PE','201717'
EXEC dbo.KR_MATRIZ_TARG 'PE','201718'
EXEC dbo.KR_MATRIZ_TARG 'PE','201801'
EXEC dbo.KR_MATRIZ_TARG 'PE','201802'


--select * from ##KR_MCC_TARGET_201714 where PKebelista=2882009--order by  AnioCampana
--select * from ##KR_MCC_COMPT where PKebelista=2882009 order by  AnioCampana


--------------------Uniendo Resultados


IF OBJECT_ID('tempdb.dbo.##KR_MCC_TARGET_T', 'U') IS NOT NULL
  DROP TABLE ##KR_MCC_TARGET_T;

SELECT *
INTO ##KR_MCC_TARGET_T
FROM 
(
--SELECT * FROM ##KR_MCC_TARGET_201712
--UNION ALL
--SELECT * FROM ##KR_MCC_TARGET_201713
--UNION ALL
--SELECT * FROM ##KR_MCC_TARGET_201714
--UNION ALL
--SELECT * FROM ##KR_MCC_TARGET_201715
--UNION ALL
SELECT * FROM ##KR_MCC_TARGET_201716
UNION ALL
SELECT * FROM ##KR_MCC_TARGET_201717
UNION ALL
SELECT * FROM ##KR_MCC_TARGET_201718
UNION ALL
SELECT * FROM ##KR_MCC_TARGET_201801
UNION ALL
SELECT * FROM ##KR_MCC_TARGET_201802
)KR
;
---(691988 row(s) affected)

--SELECT * FROM ##KR_MCC_TARGET_T
--SELECT AnioCampana,C5_Cod_Status, C5_Comp_Rolling, C5_PasoPedido,C6_Cod_Status, C6_Comp_Rolling, C6_PasoPedido,count(1) as Total FROM ##KR_MCC_DATOST group by AnioCampana,C5_Cod_Status, C5_Comp_Rolling, C5_PasoPedido,C6_Cod_Status, C6_Comp_Rolling, C6_PasoPedido
--SELECT Aniocampanat,	FlagBelcorp	,FlagGerenteRegion,	FlagGerenteZona,	FlagSociaEmpresaria	,flaginusual,COUNT(1) AS TOTAL FROM ##KR_MCC_TARGET_T GROUP BY Aniocampanat,	FlagBelcorp	,FlagGerenteRegion,	FlagGerenteZona,	FlagSociaEmpresaria	,flaginusual


--DROP TABLE KR_PRUEBA
--SELECT * INTO KR_PRUEBA FROM ##KR_MCC_TARGET_T
--618870
--SELECT AnioCampanaT,AnioCampanaUC,COUNT(*) TOTAL,count(distinct pkebelista) TOTAL_PK,( 1.0*SUM(case when cx2_pasopedido= 0 then 1 else 0 end))/COUNT(*) AS TARGET FROM ##KR_MCC_TARGET_T group by AnioCampanaT,AnioCampanaUC


IF OBJECT_ID('tempdb.dbo.##KR_MCC_TARGET_T1', 'U') IS NOT NULL
  DROP TABLE ##KR_MCC_TARGET_T1;

SELECT *
INTO ##KR_MCC_TARGET_T1
FROM 
(
SELECT A.*,CASE WHEN Cx2_PasoPedido=0 THEN 1 ELSE 0 END AS TARGET 
FROM ##KR_MCC_TARGET_T A
WHERE Cx_Activa=1
--AND FlagGerenteRegion=0 AND FlagGerenteZona=0 AND FlagSociaEmpresaria=0 
AND FlagBelcorp=0
AND FlagInusual=0 
)KR
--691988

--select * from ##KR_MCC_TARGET_T1
--SELECT Aniocampanat,FlagBelcorp,FlagGerenteRegion,FlagGerenteZona,FlagSociaEmpresaria,flaginusual,count(1) as total FROM ##KR_MCC_TARGET_T WHERE Cx_Activa=1 and Cx2_Activa=1 group by Aniocampanat,FlagBelcorp,FlagGerenteRegion,FlagGerenteZona,FlagSociaEmpresaria,flaginusual
--select * into kr_prueba from ##KR_MCC_TARGET_T---571,666
--select * from kr_prueba


IF OBJECT_ID('tempdb.dbo.##KR_TARGET_FUGA', 'U') IS NOT NULL
  DROP TABLE ##KR_TARGET_FUGA;

SELECT AnioCampanaT,AnioCampanaUC,Target,PKebelista,PKTerritorio,case when Cx_Comp_rolling= 'nuevas' then 'nuevas' when Cx_Comp_rolling in  ('Brilla','Tops','Constantes 1','Constantes 2','Constantes 3','Inconstantes')  then 'Establecidas' end as Tipo,
Cx_Status,Cx1_Status,Cx2_Status,Cx_Activa,Cx1_Activa,Cx2_Activa,Cx_Comp_Rolling,Cx1_Comp_Rolling,Cx2_Comp_Rolling,Cx_PasoPedido,Cx1_PasoPedido,Cx2_PasoPedido
INTO ##KR_TARGET_FUGA
FROM ##KR_MCC_TARGET_T1
--(691988 row(s) affected)

DELETE FROM ##KR_TARGET_FUGA WHERE Tipo IS NULL--SON LAS QUE NO TIENEN SEGMENTO
--(1564 row(s) affected)

----------------------Matriz Target Resumen

--select AnioCampanaT,AnioCampanaUC,Target,Tipo,Cx_Status,Cx1_Status,Cx2_Status,Cx_Activa,Cx1_Activa,Cx2_Activa,Cx_Comp_Rolling,Cx1_Comp_Rolling,Cx2_Comp_Rolling,Cx_PasoPedido,Cx1_PasoPedido,Cx2_PasoPedido,count(1) as total 
--from ##KR_TARGET_FUGA
--group by AnioCampanaT,AnioCampanaUC,Target,Tipo,Cx_Status,Cx1_Status,Cx2_Status,Cx_Activa,Cx1_Activa,Cx2_Activa,Cx_Comp_Rolling,Cx1_Comp_Rolling,Cx2_Comp_Rolling,Cx_PasoPedido,Cx1_PasoPedido,Cx2_PasoPedido

--SELECT * FROM ##KR_TARGET_FUGA where tipo is null
--SELECT COUNT(*) FROM ##KR_TARGET_FUGA
--517529
--SELECT tipo,COUNT(*) FROM ##KR_TARGET_FUGA group by tipo 
--517529
--SELECT AnioCampanaT,AnioCampanaUC,COUNT(*) TOTAL,count(distinct pkebelista) TOTAL_PK,( 1.0*SUM(TARGET))/COUNT(*) AS TARGET FROM ##KR_TARGET_FUGA group by AnioCampanaT,AnioCampanaUC
--SELECT * FROM ##KR_TARGET_FUGA  where cx1_status='egresada'

--SELECT aniocampanat,tipo,Target,COUNT(*) total FROM ##KR_TARGET_FUGA group by aniocampanat,tipo ,target


---Tiempo:00:02:03

--select * from ##KR_TARGET_FUGA where pkebelista=2826378
--select * from ##KR_MCC_TARGET_201715 where pkebelista=2826378
--select * from [DWH_ANALITICO].[dbo].[DWH_DEBELISTA] where pkebelista=2826378 and codpais='co'
--select * from [DWH_ANALITICO].[dbo].[DWH_FSTAEBECAM] where pkebelista=2826378 and codpais='co' order by aniocampana
--select * from [DWH_ANALITICO].[dbo].[DWH_dstatus] where codpais='co'
/*

201714	201712	0	2826378	139731	Establecidas	NORMALES	EGRESADA	REINGRESO	1	0	1	Constantes 3	Constantes 3	Inconstantes	0	0	1
201716	201714	0	2826378	139731	Establecidas	REINGRESO	NORMALES	NORMALES	1	1	1	Inconstantes	Inconstantes	Inconstantes	1	0	1
201717	201715	1	2826378	139731	Establecidas	NORMALES	NORMALES	NORMALES	1	1	1	Inconstantes	Inconstantes	Inconstantes	0	1	0

0	NUEVA	    0	REGISTRADA
1	INGRESADA	1	INGRESO
2	CONSTANTE	2	NORMALES
3	INCONSTANTE	2	NORMALES
4	REINGRESO	3	REINGRESO
5	RECODIFICADA2	NORMALES
6	EGRESADA	4	EGRESADA
7	REACTIVADA	1	INGRESO
8	REUBICADA	2	NORMALES
9	RETIRADA	5	RETIRADA
*/

---Base Consultoras Total

--DROP TABLE KR_PK;

--SELECT DISTINCT PKEBELISTA 
--INTO KR_PK
--FROM ##KR_TARGET_FUGA;
---(155133 row(s) affected)


--select * from ##KR_TARGET_FUGA


DROP TABLE ##KR_MCC_TARGET,##KR_MCC_TARGET1,##KR_MCC_COMPT,##KR_COMP_ROLLINGT,##KR_COMP_ROLLINGT1,##KR_COD_STATUST,##KR_COD_STATUST1,##FLAGPASOPEDIDOT,##FLAGPASOPEDIDOT1,##FLAG_ACTIVOT,##FLAG_ACTIVOT1,##KR_MCC_TARGET2,##KR_MCC_TARGET_201712,##KR_MCC_TARGET_201713,##KR_MCC_TARGET_201714,##KR_MCC_TARGET_T1


select distinct aniocampanaT,count(1) from ##KR_TARGET_FUGA group by aniocampanaT