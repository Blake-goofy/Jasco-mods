SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/*
 Mod     | Programmer    | Date       | Modification Description
 --------------------------------------------------------------------
 JP9     | Blake Becker  | 01/13/2026 | Flagging receipt details for QC.
*/

CREATE OR ALTER PROC [dbo].JP9_AddReceiptQC @INTERNAL_RECEIPT_LINE_NUM NUMERIC (9,0) AS

/*
 Notes
 --------------------------------------------------------------------
 Called by RECEIPT_DETAIL_A_I.
*/

SET NOCOUNT ON;

DECLARE @RECEIPT_ID AS NVARCHAR (50);
DECLARE @ITEM AS NVARCHAR (100);
DECLARE @QC_CODE AS NVARCHAR (50);
DECLARE @NEW_QTY AS INT = 0;
DECLARE @QC_SYS AS INT = (SELECT TRY_CONVERT(INT, SYSTEM_VALUE)
                          FROM SYSTEM_CONFIG_DETAIL
                          WHERE RECORD_TYPE = N'Technical'
                                AND SYS_KEY = N'JP9_QC_NEW_QTY');
DECLARE @CS_QTY AS NUMERIC (9, 5);

IF @QC_SYS IS NULL
BEGIN
    DECLARE @ErrorMessage NVARCHAR(4000) = N'The JP9 technical values are not set up properly. Missing values: JP9_QC_NEW_QTY';
    
    EXEC ADT_LogAudit 
        'JP9_AddReceiptQC',                      -- procName
        -1,                                      -- returnValue
        @ErrorMessage,                           -- message
        'Receipt Line: ', @INTERNAL_RECEIPT_LINE_NUM, -- parm1
        NULL, NULL,                              -- parm2
        NULL, NULL,                              -- parm3
        NULL, NULL,                              -- parm4
        NULL, NULL,                              -- parm5
        NULL, NULL,                              -- parm6
        NULL, NULL,                              -- parm7
        NULL, NULL,                              -- parm8
        NULL, NULL,                              -- parm9
        NULL, NULL,                              -- parm10
        SUSER_SNAME(),                           -- userName
        NULL;                                    -- warehouse
    
    RETURN;
END

--Declaring the Variables for Process History                   
DECLARE @stProcess NVARCHAR(50)
	,@stAction NVARCHAR(50)
	,@stIdentifier1 NVARCHAR(200)
	,@stIdentifier2 NVARCHAR(200)
	,@stIdentifier3 NVARCHAR(200)
	,@stIdentifier4 NVARCHAR(200)
	,@stMessage NVARCHAR(500)
	,@stProcessStamp NVARCHAR(100)
	,@stUserName NVARCHAR(30)
	,@stWarehouse NVARCHAR(25)
	,@cProcHistActive NVARCHAR(2) = NULL; -- future use

SELECT TOP 1
	@RECEIPT_ID = RECEIPT_ID
	,@ITEM = RD.ITEM
	,@QC_CODE = N'QC NEW'
	,@CS_QTY = ISNULL(CS.CONVERSION_QTY, 1)
FROM
	RECEIPT_DETAIL RD
LEFT JOIN ITEM_UNIT_OF_MEASURE CS
	ON CS.ITEM = RD.ITEM
	AND CS.QUANTITY_UM = N'CS'
WHERE
	INTERNAL_RECEIPT_LINE_NUM = @INTERNAL_RECEIPT_LINE_NUM

;WITH ALL_ITEMS AS (
	--SELECT DISTINCT
	--	ITEM
	--FROM
	--	AR_ILS.dbo.AR_RECEIPT_DETAIL RD
	--INNER JOIN AR_ILS.dbo.AR_RECEIPT_HEADER RH
	--	ON RH.INTERNAL_RECEIPT_NUM = RD.INTERNAL_RECEIPT_NUM
	--WHERE
	--	RD.TOTAL_QTY > 60
	--	AND (RD.OPEN_QTY < RD.TOTAL_QTY
	--		OR RH.USER_DEF1 = N'Printed')

	--UNION

	SELECT DISTINCT
		ITEM
	FROM
		RECEIPT_DETAIL RD
	INNER JOIN RECEIPT_HEADER RH
		ON RH.INTERNAL_RECEIPT_NUM = RD.INTERNAL_RECEIPT_NUM
	WHERE
		RD.TOTAL_QTY > 60
		AND (RD.OPEN_QTY < RD.TOTAL_QTY
			OR RH.USER_DEF1 = N'Printed')
)

UPDATE RECEIPT_DETAIL SET
	ITEM_CATEGORY7 = @QC_CODE
	,USER_DEF1 = @QC_SYS -- Requesting 2 eaches for QC NEW (one for the content team to photograph, one for the graphic designer to verify the art)
	,DATE_TIME_STAMP = GETDATE()
	,PROCESS_STAMP = N'JP9_AddReceiptQC'
WHERE
	INTERNAL_RECEIPT_LINE_NUM = @INTERNAL_RECEIPT_LINE_NUM
	AND TOTAL_QTY > 60
	AND ITEM NOT IN (SELECT ITEM FROM ALL_ITEMS)

IF @@ROWCOUNT > 0 -- If we updated any rows
BEGIN
	
	SET @stProcess = N'600' -- QC Assignment
	SET @stAction = N'150' -- Information
	SET @stIdentifier1 = CONCAT(N'Receipt ID: ',@RECEIPT_ID)
	SET @stIdentifier2 = CONCAT(N'Item: ',@ITEM)
	SET @stIdentifier3 = CONCAT(N'Internal line num: ',@INTERNAL_RECEIPT_LINE_NUM)
	SET @stMessage = CONCAT(N'Item ',@ITEM, N' from receipt ID ', @RECEIPT_ID, N' was marked ', @QC_CODE, N' because the item has never been checked in as a ', @QC_CODE)
	SET @stProcessStamp = N'JP9_AddReceiptQC'
	SET @stUserName = SUSER_SNAME()

	EXEC HIST_SaveProcHist @stProcess
		,@stAction
		,@stIdentifier1
		,@stIdentifier2
		,@stIdentifier3
		,@stIdentifier4
		,@stMessage
		,@stProcessStamp
		,@stUserName
		,@stWarehouse
		,@cProcHistActive

	SET @QC_CODE = N'QC NEW TIMER'
	SET @NEW_QTY = @QC_SYS
END
ELSE
BEGIN
	SET @QC_CODE = N'QC TIMER'
END

;WITH TIMER AS (
	SELECT
		ITEM = LEFT(ITEM, CASE WHEN CHARINDEX('-', ITEM) = 0 THEN LEN(ITEM) ELSE CHARINDEX('-', ITEM) END - 1)
		,PURCHASE_ORDER_ID
	FROM
		RECEIPT_DETAIL
	WHERE
		TOTAL_QTY >= 400
		AND PURCHASE_ORDER_ID IS NOT NULL
		AND ITEM NOT LIKE N'%MEX%'
		AND ITEM_DESC LIKE N'%timer%'
		AND OPEN_QTY < TOTAL_QTY
)

UPDATE RECEIPT_DETAIL SET
	ITEM_CATEGORY7 = @QC_CODE
	,USER_DEF1 = CONVERT(NVARCHAR(25), @NEW_QTY + CONVERT(INT, CASE WHEN TOTAL_QTY > 9999 AND @CS_QTY < 5 THEN 2 * @CS_QTY ELSE @CS_QTY END)) -- Logic by Rayce Swann
	,DATE_TIME_STAMP = GETDATE()
	,PROCESS_STAMP = N'JP9_AddReceiptQC'
FROM
	RECEIPT_DETAIL RD
LEFT JOIN TIMER T
	ON T.ITEM = LEFT(RD.ITEM, CASE WHEN CHARINDEX('-', RD.ITEM) = 0 THEN LEN(RD.ITEM) ELSE CHARINDEX('-', RD.ITEM) END - 1)
	AND T.PURCHASE_ORDER_ID = RD.PURCHASE_ORDER_ID
WHERE
	RD.INTERNAL_RECEIPT_LINE_NUM = @INTERNAL_RECEIPT_LINE_NUM
	AND RD.TOTAL_QTY >= 400
	AND RD.ITEM NOT LIKE N'%MEX%'
	AND RD.ITEM_DESC LIKE N'%timer%'
	AND RD.PURCHASE_ORDER_ID IS NOT NULL
	AND T.ITEM IS NULL -- This item / PO has never been TIMER QC'd

IF @@ROWCOUNT > 0 -- If we updated any rows
BEGIN
	SET @stProcess = N'600' -- QC Assignment
	SET @stAction = N'150' -- Information
	SET @stIdentifier1 = CONCAT(N'Receipt ID: ',@RECEIPT_ID)
	SET @stIdentifier2 = CONCAT(N'Item: ',@ITEM)
	SET @stIdentifier3 = CONCAT(N'Internal line num: ',@INTERNAL_RECEIPT_LINE_NUM)
	SET @stMessage = CONCAT(N'Item ',@ITEM, N' from receipt ID ', @RECEIPT_ID, N' was marked ', @QC_CODE, N' because the item / PO combination has never been checked in as a ', @QC_CODE)
	SET @stProcessStamp = N'JP9_AddReceiptQC'
	SET @stUserName = N'ILSSRV'

	EXEC HIST_SaveProcHist @stProcess
		,@stAction
		,@stIdentifier1
		,@stIdentifier2
		,@stIdentifier3
		,@stIdentifier4
		,@stMessage
		,@stProcessStamp
		,@stUserName
		,@stWarehouse
		,@cProcHistActive
END
GO


