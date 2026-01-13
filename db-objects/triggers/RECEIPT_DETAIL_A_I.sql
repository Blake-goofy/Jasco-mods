USE [JPCISCALEQA2025]
GO

/****** Object:  Trigger [dbo].[RECEIPT_DETAIL_A_I]    Script Date: 1/13/2026 10:31:00 AM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO



/*
 Mod     | Programmer    | Date       | Modification Description
 --------------------------------------------------------------------
 001     | Blake Becker  | 06/29/2025 | Correcting TOTAL_LINES for all receivers.
 JP9     | Blake Becker  | 01/13/2026 | Call JP9_AddReceiptQC to flag lines as QC.
*/

ALTER TRIGGER [dbo].[RECEIPT_DETAIL_A_I]
ON [dbo].[RECEIPT_DETAIL]
AFTER INSERT
AS

SET NOCOUNT ON;

DECLARE @INTERNAL_RECEIPT_LINE_NUM NUMERIC (9,0) = (SELECT INTERNAL_RECEIPT_LINE_NUM FROM inserted)

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

DECLARE @RECEIPTS TABLE (
    INTERNAL_RECEIPT_NUM NUMERIC(9,0), 
    DETAIL_LINES NUMERIC(9,0),
    TOTAL_LINES NUMERIC(9,0)

)

-- Correcting TOTAL_LINES for all receivers
INSERT INTO @RECEIPTS
SELECT
    RH.INTERNAL_RECEIPT_NUM
    ,DETAIL_LINES = COUNT(DISTINCT RD.INTERNAL_RECEIPT_LINE_NUM)
    ,TOTAL_LINES
FROM
	RECEIPT_DETAIL RD
	INNER JOIN RECEIPT_HEADER RH
		ON RH.INTERNAL_RECEIPT_NUM = RD.INTERNAL_RECEIPT_NUM
GROUP BY
    RH.TOTAL_LINES, RH.INTERNAL_RECEIPT_NUM
HAVING
    ISNULL(RH.TOTAL_LINES,0) != COUNT(DISTINCT RD.INTERNAL_RECEIPT_LINE_NUM)
    
UPDATE RH SET
	RH.TOTAL_LINES = R.DETAIL_LINES
FROM
    RECEIPT_HEADER RH
INNER JOIN @RECEIPTS R
	ON R.INTERNAL_RECEIPT_NUM = RH.INTERNAL_RECEIPT_NUM

IF EXISTS (SELECT 1 FROM @RECEIPTS)
BEGIN
    DECLARE @CurrentReceiptNum NUMERIC(9,0)
    DECLARE @CurrentDetailLines NUMERIC(9,0)
    DECLARE @CurrentTotalLines NUMERIC(9,0)
    DECLARE @ReceiptID NVARCHAR(25)
    
    WHILE EXISTS (SELECT 1 FROM @RECEIPTS)
    BEGIN
        SELECT TOP 1
            @CurrentReceiptNum = INTERNAL_RECEIPT_NUM,
            @CurrentDetailLines = DETAIL_LINES,
            @CurrentTotalLines = TOTAL_LINES
        FROM @RECEIPTS
        
        SELECT @ReceiptID = RECEIPT_ID, @stWarehouse = WAREHOUSE
        FROM RECEIPT_HEADER
        WHERE INTERNAL_RECEIPT_NUM = @CurrentReceiptNum
        
        SET @stProcess = N'Value changed'
        SET @stAction = N'150' -- Information
        SET @stIdentifier1 = @ReceiptID
        SET @stIdentifier2 = N'TOTAL_LINES corrected'
        SET @stIdentifier3 = CONVERT(NVARCHAR(200), @CurrentTotalLines)
        SET @stIdentifier4 = CONVERT(NVARCHAR(200), @CurrentDetailLines)
        SET @stMessage = N'Receipt ' + @ReceiptID + N' TOTAL_LINES corrected from ' 
                       + CONVERT(NVARCHAR(10), @CurrentTotalLines) + N' to ' 
                       + CONVERT(NVARCHAR(10), @CurrentDetailLines) + N'.'
        SET @stProcessStamp = N'RECEIPT_DETAIL_A_I Trigger'
        SET @stUserName = SUSER_SNAME()
        
        EXEC HIST_SaveProcHist @stProcess, @stAction, @stIdentifier1, @stIdentifier2, 
                               @stIdentifier3, @stIdentifier4, @stMessage, @stProcessStamp, 
                               @stUserName, @stWarehouse, @cProcHistActive
        
        DELETE FROM @RECEIPTS WHERE INTERNAL_RECEIPT_NUM = @CurrentReceiptNum
    END
END

EXEC JP9_AddReceiptQC @INTERNAL_RECEIPT_LINE_NUM