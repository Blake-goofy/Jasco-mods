SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/*
 Mod     | Programmer    | Date       | Modification Description
 --------------------------------------------------------------------
 JP9     | Blake Becker  | 01/13/2026 | Remove receipt QC to avoid duplicates.
*/

CREATE OR ALTER PROC [dbo].JP9_RemoveReceiptQC @INTERNAL_RECEIPT_NUM NUMERIC (9,0), @REASON NVARCHAR (MAX) AS

/*
 Notes
 --------------------------------------------------------------------
 Called by RECEIPT_DETAIL_A_I.
*/
SET NOCOUNT ON;

DECLARE @TRAILER_ID NVARCHAR (25)
DECLARE @SYS_USER NVARCHAR (25) = SUSER_SNAME()
DECLARE @REC_DATE DATETIME
DECLARE @QC_NEW_QTY AS INT = (SELECT TRY_CONVERT(INT, SYSTEM_VALUE)
                              FROM SYSTEM_CONFIG_DETAIL
                              WHERE RECORD_TYPE = N'Technical'
                                    AND SYS_KEY = N'JP9_QC_NEW_QTY');

IF @QC_NEW_QTY IS NULL
BEGIN
    DECLARE @ErrorMessage NVARCHAR(4000) = N'The JP9 technical values are not set up properly. Missing values: JP9_QC_NEW_QTY';
    
    EXEC ADT_LogAudit 
        'JP9_RemoveReceiptQC',                   -- procName
        -1,                                      -- returnValue
        @ErrorMessage,                           -- message
        'Receipt Line: ', @INTERNAL_RECEIPT_NUM, -- parm1
        NULL, NULL,                              -- parm2
        NULL, NULL,                              -- parm3
        NULL, NULL,                              -- parm4
        NULL, NULL,                              -- parm5
        NULL, NULL,                              -- parm6
        NULL, NULL,                              -- parm7
        NULL, NULL,                              -- parm8
        NULL, NULL,                              -- parm9
        NULL, NULL,                              -- parm10
        @SYS_USER,			                     -- userName
        NULL;                                    -- warehouse
    
    RETURN;
END

;WITH CASE_QTY AS (
	SELECT RD.ITEM, CS_QTY = MAX(ISNULL(CS.CONVERSION_QTY, 1))
	FROM RECEIPT_DETAIL RD
	LEFT JOIN ITEM_UNIT_OF_MEASURE CS
		ON CS.ITEM = RD.ITEM
		AND CS.QUANTITY_UM = N'CS'
	GROUP BY RD.ITEM
)

UPDATE RECEIPT_DETAIL SET
	USER_DEF1 = 
		CASE
			WHEN ITEM_CATEGORY7 LIKE N'QC NEW' THEN CONVERT(NVARCHAR(25), @QC_NEW_QTY)
			WHEN ITEM_CATEGORY7 = N'QC NEW TIMER' THEN CONVERT(NVARCHAR(25), @QC_NEW_QTY +
				CONVERT(INT, CASE WHEN TOTAL_QTY > 9999 AND CS.CS_QTY < 5 THEN 2 * CS.CS_QTY ELSE CS.CS_QTY END))
			WHEN ITEM_CATEGORY7 LIKE N'QC TIMER' THEN CONVERT(NVARCHAR(25),
				CONVERT(INT, CASE WHEN TOTAL_QTY > 9999 AND CS.CS_QTY < 5 THEN 2 * CS.CS_QTY ELSE CS.CS_QTY END))
			ELSE RD.USER_DEF1
		END
FROM
	RECEIPT_DETAIL RD
LEFT JOIN CASE_QTY CS
	ON CS.ITEM = RD.ITEM
WHERE
	ITEM_CATEGORY7 LIKE N'QC%'
	AND ITEM_CATEGORY7 != N'QC' AND
	CASE
		WHEN TRY_CONVERT(INT, RD.USER_DEF1) IS NULL THEN N'Y'
		WHEN ITEM_CATEGORY7 LIKE N'QC NEW' AND CONVERT(INT, RD.USER_DEF1) != @QC_NEW_QTY THEN N'Y'
		WHEN ITEM_CATEGORY7 = N'QC NEW TIMER' AND CONVERT(INT, RD.USER_DEF1) != @QC_NEW_QTY +
			CONVERT(INT, CASE WHEN TOTAL_QTY > 9999 AND CS.CS_QTY < 5 THEN 2 * CS.CS_QTY ELSE CS.CS_QTY END) THEN N'Y'
		WHEN ITEM_CATEGORY7 LIKE N'QC TIMER' AND CONVERT(INT, RD.USER_DEF1) !=
			CONVERT(INT, CASE WHEN TOTAL_QTY > 9999 AND CS.CS_QTY < 5 THEN 2 * CS.CS_QTY ELSE CS.CS_QTY END) THEN N'Y'
		ELSE N'N'
	END = N'Y'

SELECT @TRAILER_ID = TRAILER_ID, @REC_DATE = ISNULL(RECEIPT_DATE, N'0')
FROM RECEIPT_HEADER WHERE INTERNAL_RECEIPT_NUM = @INTERNAL_RECEIPT_NUM

DECLARE @LINES TABLE (
	INTERNAL_RECEIPT_LINE_NUM NUMERIC (9,0)
	,ITEM NVARCHAR (25)
	,PURCHASE_ORDER_ID NVARCHAR (25)
)

;WITH QC_LINES AS (
	SELECT
		RD.INTERNAL_RECEIPT_LINE_NUM
		,RD.ITEM
		,RD.PURCHASE_ORDER_ID
		,NUM = ROW_NUMBER() OVER (PARTITION BY RD.ITEM ORDER BY RD.PURCHASE_ORDER_ID)
	FROM
		RECEIPT_HEADER RH
	INNER JOIN RECEIPT_DETAIL RD
		ON RD.INTERNAL_RECEIPT_NUM = RH.INTERNAL_RECEIPT_NUM
	WHERE
		RH.TRAILER_ID = @TRAILER_ID
		AND RH.RECEIPT_DATE = @REC_DATE
		AND RD.ITEM_CATEGORY7 LIKE N'QC%'
)

INSERT @LINES
SELECT
	INTERNAL_RECEIPT_LINE_NUM
	,ITEM
	,PURCHASE_ORDER_ID
FROM
	QC_LINES
WHERE
	NUM = 1

DECLARE @REMOVE_QC TABLE (
	INTERNAL_RECEIPT_LINE_NUM NUMERIC (9,0)
	,RECEIPT_ID NVARCHAR (50)
	,ITEM NVARCHAR (100)
	,ITEM_CATEGORY7 NVARCHAR (100)
)

-- Collect lines that are marked QC NEW for the same item as the one being checked in
INSERT INTO @REMOVE_QC
SELECT
	RD.INTERNAL_RECEIPT_LINE_NUM
	,RD.RECEIPT_ID
	,RD.ITEM
	,RD.ITEM_CATEGORY7
FROM
    RECEIPT_DETAIL RD
INNER JOIN @LINES L
	ON RD.ITEM = L.ITEM
WHERE
    RD.INTERNAL_RECEIPT_LINE_NUM NOT IN (SELECT INTERNAL_RECEIPT_LINE_NUM FROM @LINES)
    AND RD.OPEN_QTY = RD.TOTAL_QTY
    AND (
        RD.ITEM_CATEGORY7 = N'QC NEW'
        OR (
			(RD.ITEM_CATEGORY7 LIKE N'QC NEW %' OR RD.ITEM_CATEGORY7 NOT LIKE N'%NEW%')
			AND RD.PURCHASE_ORDER_ID = L.PURCHASE_ORDER_ID
		)
    )
	AND RD.ITEM_CATEGORY7 LIKE N'QC%'

-- Remove the QC flag or adjust the QC category as needed
UPDATE RECEIPT_DETAIL
SET
    ITEM_CATEGORY7 = 
        CASE 
            WHEN ITEM_CATEGORY7 NOT LIKE N'%NEW%' THEN NULL
            WHEN ITEM_CATEGORY7 = N'QC NEW' THEN NULL
            WHEN ITEM_CATEGORY7 LIKE N'QC NEW %' THEN 
                N'QC' + SUBSTRING(ITEM_CATEGORY7, LEN(N'QC NEW ') + 1, LEN(ITEM_CATEGORY7))
            ELSE ITEM_CATEGORY7
        END
    ,USER_DEF1 =
        CASE
            WHEN ITEM_CATEGORY7 NOT LIKE N'%NEW%' THEN NULL
            WHEN ITEM_CATEGORY7 = N'QC NEW' THEN NULL
            WHEN TRY_CONVERT(INT, USER_DEF1) IS NOT NULL AND ITEM_CATEGORY7 LIKE N'QC NEW %' THEN CONVERT(INT, USER_DEF1) - @QC_NEW_QTY
            ELSE USER_DEF1
        END
    ,DATE_TIME_STAMP = GETDATE()
    ,PROCESS_STAMP = N'JP9_RemoveReceiptQC'
WHERE
    INTERNAL_RECEIPT_LINE_NUM IN (SELECT INTERNAL_RECEIPT_LINE_NUM FROM @REMOVE_QC)

-- Insert process history for each line where QC was removed
IF @@ROWCOUNT > 0 -- If we updated any rows
BEGIN
	WHILE EXISTS (SELECT INTERNAL_RECEIPT_LINE_NUM FROM @REMOVE_QC)
	BEGIN
		--Declaring the Variables for Process History                   
		DECLARE @stProcess NVARCHAR(50)
		DECLARE @stAction NVARCHAR(50)
		DECLARE @stIdentifier1 NVARCHAR(200)
		DECLARE @stIdentifier2 NVARCHAR(200)
		DECLARE @stIdentifier3 NVARCHAR(200)
		DECLARE @stIdentifier4 NVARCHAR(200)
		DECLARE @stMessage NVARCHAR(500)
		DECLARE @stProcessStamp NVARCHAR(100)
		DECLARE @stUserName NVARCHAR(30)
		DECLARE @stWarehouse NVARCHAR(25)
		DECLARE @cProcHistActive NVARCHAR(2) = NULL; -- future use

		DECLARE @PROCESS_ITEM NVARCHAR (100)
		DECLARE @PROCESS_RECEIPT NVARCHAR (50)
		DECLARE @PROCESS_LINE NUMERIC (9,0)
		DECLARE @ITEM_CATEGORY7 NVARCHAR (100)

		SELECT TOP 1
			@PROCESS_LINE = INTERNAL_RECEIPT_LINE_NUM
			,@PROCESS_RECEIPT = RECEIPT_ID
			,@PROCESS_ITEM = ITEM
			,@ITEM_CATEGORY7 = ITEM_CATEGORY7
		FROM
			@REMOVE_QC
				
		SET @stProcess = N'610' -- QC Evaluation
		SET @stAction = N'150' -- Information
		SET @stIdentifier1 = CONCAT(N'Receipt ID: ',@PROCESS_RECEIPT)
		SET @stIdentifier2 = CONCAT(N'Item: ',@PROCESS_ITEM)
		SET @stIdentifier3 = CONCAT(N'Internal line num: ',@PROCESS_LINE)
		SET @stMessage =
			CASE
				WHEN @ITEM_CATEGORY7 = N'QC NEW' THEN CONCAT(N'QC NEW removed for item ',@PROCESS_ITEM, N' from receipt ID ', @PROCESS_RECEIPT, N' because a different line of the same item was ', @REASON)
				ELSE CONCAT(N'QC NEW removed for item ',@PROCESS_ITEM, N' from receipt ID ', @PROCESS_RECEIPT, N' because a different line of the same item / PO combination was ', @REASON)
			END
		SET @stProcessStamp = N'JP9_RemoveReceiptQC'
		SET @stUserName = N'System'

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

		DELETE @REMOVE_QC WHERE INTERNAL_RECEIPT_LINE_NUM = @PROCESS_LINE
	END
END

GO
