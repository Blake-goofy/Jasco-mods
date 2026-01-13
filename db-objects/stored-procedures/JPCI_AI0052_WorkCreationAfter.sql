SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO




/*
 Mod     | Programmer    | Date		   | Modification Description
 --------------------------------------------------------------------
  AI0052 | gmishra		 | 06/4/2019   | Stored Procedure for exit point:Work Creation - After
		 | blacob		 | 08/10/2023  | assign ud1 logic to location inventory for decant replens
		 | blacob        | 08/15/2023  | assign ud1 logic to replen work instructions
		 | blacob		 | 09.26.2023  | added some cycle count/empty pallet logic at then end.
		 | bbecker		 | 05/28/2024  | Commented out old Decant UD1 logic
		 | bbecker		 | 05/30/2024  | Added a check to ensure I only run decant logic when going to DECANT
		 | bbecker		 | 06/04/2024  | Commented out empty location logic, now handling in sched job
		 | bbecker		 | 06/12/2024  | Cleaned up commented out logic and now deleting cycle count headers that don't have details
		 | bbecker		 | 06/19/2024  | Sending internal_instruction_num instead of work_unit to usp_JPCI_DecantUD1 for EX26
 001	 | Blake Becker	 | 08/05/2024  | Added call to usp_JPCI_DecantUD1
 002	 | Blake Becker	 | 08/27/2024  | Removed old UD1 logic
 JP10	 | Blake Becker	 | 12/16/2024  | Last pallet checked in gets put on hold
 004	 | Blake Becker	 | 08/18/2025  | Overallocation revamp
*/

CREATE OR ALTER PROCEDURE [dbo].[JPCI_AI0052_WorkCreationAfter] (
    @SESSIONVALUE xml,
    @PROCESS nvarchar(max),
    @LAUNCHNUM nvarchar(max)
)
AS 

IF EXISTS (SELECT 1 FROM WORK_INSTRUCTION W WITH (NOLOCK) WHERE W.LAUNCH_NUM = @LAUNCHNUM AND W.TO_TEMPL_FIELD1 = N'DECANT' AND ISNULL(W.USER_DEF1,N'') = N'')
BEGIN
	EXEC usp_JPCI_DecantUD1

	DECLARE @ITEMS TABLE (ITEM NVARCHAR (50))
	DECLARE @ITEM NVARCHAR (50)

	INSERT @ITEMS
	SELECT DISTINCT ITEM FROM WORK_INSTRUCTION WHERE LAUNCH_NUM = @LAUNCHNUM AND ITEM IS NOT NULL

	WHILE EXISTS (SELECT 1 FROM @ITEMS)
	BEGIN
		SELECT TOP 1 @ITEM = ITEM FROM @ITEMS
		EXEC usp_ChangePriority NULL, @ITEM
		DELETE @ITEMS WHERE ITEM = @ITEM
	END
		
END
	
	
BEGIN --step 2: Populate UD2 with the FROM_LOC's pick sequence for picking work or with the TO_LOC's putaway sequence for replenishment work. For Group picking Order By.
	
update	w
	
set		w.USER_DEF2 = case when w.WORK_GROUP = 'Picking' then pick.PICKING_SEQ when w.WORK_GROUP = 'Replenishment' then puts.PUTAWAY_SEQ else null end
	
from	WORK_INSTRUCTION w
			inner join (select [LOCATION],PICKING_SEQ from [LOCATION]) pick on w.FROM_LOC = pick.[LOCATION]
			inner join (select [LOCATION],PUTAWAY_SEQ from [LOCATION]) puts on w.TO_LOC = puts.[LOCATION]
	
where	w.LAUNCH_NUM = @LAUNCHNUM
		and w.INSTRUCTION_TYPE = 'Detail'
		and w.USER_DEF2 is null
		and
		(
			(w.WORK_GROUP = 'Picking' and w.WORK_TYPE in ('Loose Pick - Parcel','Loose Pick - LTL','Overpack - LTL','Overpack - Parcel')) --any picking that would be grouped
			or
			(w.WORK_GROUP = 'Replenishment') --for applying the put sequence to replen work
		);
	
END --step 2

DELETE W FROM WORK_INSTRUCTION W
LEFT JOIN WORK_INSTRUCTION C ON C.PARENT_INSTR = W.INTERNAL_INSTRUCTION_NUM
WHERE 
W.INSTRUCTION_TYPE = 'Header'
AND W.FROM_LOC IS NULL
AND W.WORK_TYPE = 'Empty Location Check'
AND C.INTERNAL_INSTRUCTION_NUM IS NULL--NO CHILDREN
AND W.LAUNCH_NUM = @LAUNCHNUM

-- JP10 START
DECLARE @JP10_UpdatedRows INT = 0;

WITH LaunchWorkUnits AS (
    -- Step 1: Get work units for this launch's receipt putaway
    SELECT W.WORK_UNIT
    FROM WORK_INSTRUCTION W
    WHERE W.WORK_TYPE = N'Receipt Putaway' 
        AND W.LAUNCH_NUM = @LAUNCHNUM
),
RelatedReceiptLine AS (
    -- Step 2: Find the receipt line for these work units
    SELECT TOP 1 
        RC.INTERNAL_RECEIPT_LINE_NUM,
        RD.OPEN_QTY
    FROM RECEIPT_CONTAINER RC
    INNER JOIN RECEIPT_DETAIL RD 
        ON RD.INTERNAL_RECEIPT_LINE_NUM = RC.INTERNAL_RECEIPT_LINE_NUM
    WHERE RC.CONTAINER_ID IN (SELECT WORK_UNIT FROM LaunchWorkUnits)
        AND RD.OPEN_QTY = 0  -- Only process if all pallets checked in
),
LastPallet AS (
    -- Step 3: Get the last container from that receipt line
    SELECT MAX(RC.INTERNAL_REC_CONT_NUM) AS INTERNAL_REC_CONT_NUM
    FROM RECEIPT_CONTAINER RC
    WHERE RC.INTERNAL_RECEIPT_LINE_NUM IN (
        SELECT INTERNAL_RECEIPT_LINE_NUM FROM RelatedReceiptLine
    )
)
UPDATE W
SET W.HOLD_CODE = N'LAST PALLET'
FROM WORK_INSTRUCTION W
INNER JOIN RECEIPT_CONTAINER RC 
    ON RC.CONTAINER_ID = W.WORK_UNIT
INNER JOIN LastPallet LP 
    ON LP.INTERNAL_REC_CONT_NUM = RC.INTERNAL_REC_CONT_NUM;

SET @JP10_UpdatedRows = @@ROWCOUNT;

-- Log process history for last pallet holds
IF @JP10_UpdatedRows > 0
BEGIN
    DECLARE @stProcess NVARCHAR(50) = N'340'; -- Work creation
    DECLARE @stAction NVARCHAR(50) = N'150'; -- Information
    DECLARE @stIdentifier1 NVARCHAR(200) = @LAUNCHNUM;
    DECLARE @stIdentifier2 NVARCHAR(200) = CONVERT(NVARCHAR(10), @JP10_UpdatedRows);
    DECLARE @stIdentifier3 NVARCHAR(200);
    DECLARE @stIdentifier4 NVARCHAR(200);
    DECLARE @stMessage NVARCHAR(500) = CONVERT(NVARCHAR(10), @JP10_UpdatedRows) 
                                           + N' last pallet work instruction(s) placed on hold for count verification.';
    DECLARE @stProcessStamp NVARCHAR(100) = N'JPCI_AI0052_WorkCreationAfter';
    DECLARE @stUserName NVARCHAR(30) = SUSER_SNAME();
    DECLARE @stWarehouse NVARCHAR(25);
    DECLARE @cProcHistActive NVARCHAR(2) = NULL;
    
    SELECT TOP 1 @stWarehouse = FROM_WHS 
    FROM WORK_INSTRUCTION 
    WHERE LAUNCH_NUM = @LAUNCHNUM;
    
    EXEC HIST_SaveProcHist @stProcess, @stAction, @stIdentifier1, @stIdentifier2, 
                           @stIdentifier3, @stIdentifier4, @stMessage, @stProcessStamp, 
                           @stUserName, @stWarehouse, @cProcHistActive;
END
-- JP10 END

GO
