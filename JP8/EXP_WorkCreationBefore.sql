SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/*
 Mod		 | Programmer   | Date       | Modification Description
 --------------------------------------------------------------------
             | jsanders		| 6/18/2020  | Stored Procedure for exit point:Work Creation - Before
 001		 | jsanders		| 6/09/2021  | commented out replen logic. added cycle count request logic to apply location's template_field 1 and 2 to request's UD 1 and 2 respectively. this is to change work unit grouping.
 002		 | bbecker		| 5/05/2023  | Added CP/AM flag on UD3 of inventory management work data
 003		 | bbecker		| 5/08/2023  | Added CP/AM flag on UD5 of replenishment request
 004		 | blacob		| 9/20/2023  | corrected AM/CP logic for inventory management and replenishment requests
 005		 | bbecker		| 11/30/2023 | Return AL qty to FRED
 JP8		 | Blake Becker | 03/12/2024 | Return dock area anchor criteria to location
 007		 | blash		| 03/13/2024 | Removed return AL qty to FRED
 008		 | Blake Becker	| 08/05/2024 | Added call to usp_JPCI_DecantUD1
 009		 | Nash Kibler	| 08/05/2024 | Removed call to usp_JPCI_DecantUD1
*/

CREATE OR ALTER PROCEDURE [dbo].[EXP_WorkCreationBefore] (
    @SESSIONVALUE xml,
    @PROCESS nvarchar(max),
    @LAUNCHNUM nvarchar(max)
)
AS 
    SET NOCOUNT ON;

-- JP8 START
DECLARE @JP8_DOCK_AREA AS NVARCHAR (200);

-- Process history variables
DECLARE @stProcess AS NVARCHAR(50) = N'JP8_MinWeightStageRedirect',
        @stAction AS NVARCHAR(50),
        @stIdentifier1 AS NVARCHAR(200),
        @stIdentifier2 AS NVARCHAR(200),
        @stIdentifier3 AS NVARCHAR(200),
        @stIdentifier4 AS NVARCHAR(200),
        @stMessage AS NVARCHAR(500),
        @stProcessStamp AS NVARCHAR(100) = N'EXP_WorkCreationBefore',
        @stUserName AS NVARCHAR(30) = SUSER_SNAME(),
        @stWarehouse AS NVARCHAR(25),
        @cProcHistActive AS NVARCHAR(2) = NULL;

SELECT @JP8_DOCK_AREA = SYSTEM_VALUE
FROM SYSTEM_CONFIG_DETAIL
WHERE RECORD_TYPE = N'Technical'
      AND SYS_KEY = N'JP8_DOCK_AREA';

IF @JP8_DOCK_AREA IS NULL
BEGIN
    -- LOG AUDIT
    DECLARE @ErrorMessage NVARCHAR(4000) = N'The JP8 technical values are not set up properly. Missing values: JP8_DOCK_AREA';
    
    EXEC ADT_LogAudit 
        'EXP_WorkCreationBefore',                -- procName
        -1,                                      -- returnValue
        @ErrorMessage,                           -- message
        'Launch: ', @LAUNCHNUM,                  -- parm1
        NULL, NULL,                              -- parm2
        NULL, NULL,                              -- parm3
        NULL, NULL,                              -- parm4
        NULL, NULL,                              -- parm5
        NULL, NULL,                              -- parm6
        NULL, NULL,                              -- parm7
        NULL, NULL,                              -- parm8
        NULL, NULL,                              -- parm9
        NULL, NULL,                              -- parm10
        @stUserName,                             -- userName
        NULL;                                    -- warehouse
    
END

IF EXISTS (SELECT 1
           FROM LOCATION
           WHERE USER_DEF1 = @JP8_DOCK_AREA)
    BEGIN
        DECLARE @DOCK_AREA_DESC NVARCHAR(50);
        DECLARE @LocationsAffected INT;
        
        SELECT @DOCK_AREA_DESC = DESCRIPTION
        FROM FILTER_CONFIG_DETAIL
        WHERE OBJECT_ID = TRY_CONVERT(NUMERIC(9,0), @JP8_DOCK_AREA);
        
        UPDATE LOCATION
        SET DOCK_AREA_ANCHOR_CRITERIA = USER_DEF1,
            USER_DEF1                 = NULL,
            PROCESS_STAMP             = 'EXP_WorkCreationBefore',
            USER_STAMP                = SUSER_SNAME(),
            DATE_TIME_STAMP           = GETUTCDATE()
        WHERE USER_DEF1 = @JP8_DOCK_AREA;  -- USER_DEF1 set by EXP_CloseContainerAfter
        
        SET @LocationsAffected = @@ROWCOUNT;
        
        IF @LocationsAffected > 0
        BEGIN
            SET @stAction = N'150'; -- Information
            SET @stIdentifier1 = @LAUNCHNUM;
            SET @stMessage = N'Returning dock area anchor criteria to ' 
                           + CONVERT(NVARCHAR(10), @LocationsAffected) 
                           + N' locations for ' + ISNULL(@DOCK_AREA_DESC, N'NULL') + N'.';
            
            EXEC HIST_SaveProcHist @stProcess, @stAction, @stIdentifier1, @stIdentifier2, @stIdentifier3, 
                                   @stIdentifier4, @stMessage, @stProcessStamp, @stUserName, @stWarehouse, @cProcHistActive;
        END
    END

-- JP8 END



--cycle count request update
BEGIN

update ccr

set ccr.USER_DEF1 = l.TEMPLATE_FIELD1
   ,ccr.USER_DEF2 = l.TEMPLATE_FIELD2
   ,ccr.USER_DEF4 = l.TEMPLATE_FIELD4
   ,ccr.USER_DEF6 = l.USER_DEF6

from CYCLE_COUNT_REQUEST ccr
inner join CYCLE_COUNT_PLAN ccp on ccr.INTERNAL_PLAN_NUM = ccp.INTERNAL_PLAN_NUM
inner join LOCATION l on ccr.LOCATION = l.LOCATION and ccr.WAREHOUSE = l.warehouse

where
ccr.LAUNCH_NUMBER = @LAUNCHNUM
--and ccp.MASTER_NAME in ('500 all uncounted','AMHE all uncounted') --currently allowing all cc work to group by area/aisle.
and ccr.USER_DEF1 is null
and ccr.USER_DEF2 is null
and ccr.USER_DEF4 is null;

END;


--inventory management work data update
BEGIN

update i
--set i.USER_DEF3 = (i.QUANTITY / p.CONVERSION_QTY)*100 --Blake B commented out 5/5/2023
set i.USER_DEF3 = --Blake B 5/5/2023
case
	when l.LOCATION_TYPE = 'Inner Pack 1 pallet rack' then 'IP' --9.18.23
	--when ((i.QUANTITY/li.ON_HAND_QTY) = '1' or (i.QUANTITY/p.CONVERSION_QTY) > '0.25') then 'Aisle Master'
	when (li.ON_HAND_QTY-li.ALLOCATED_QTY)=0 or (i.QUANTITY/p.CONVERSION_QTY) > 0.25 then 'Aisle Master'
	else 'Cherry Picker'
end
from INV_MGMT_WORK_DATA i
left join ITEM_UNIT_OF_MEASURE p on i.ITEM = p.ITEM and p.QUANTITY_UM = 'PL'
left join LOCATION_INVENTORY li on i.FROM_LOC = li.LOCATION --Blake B 5/5/2023
left join LOCATION l on i.TO_LOC = l.LOCATION --9.18.23
--where i.WORK_CREATED = 'N'
where i.WORK_CREATED != 'Y'
and isnull(p.CONVERSION_QTY,0) != 0
--and i.TO_LOC = 'DECANT'


END;

--new version because replen swap to decant quit working
BEGIN

update r
set r.USER_DEF5 =
case
	when l.LOCATION_TYPE = 'Inner Pack 1 pallet rack' then 'IP' --9.18.23
    --when ((r.ALLOCATED_QTY/li.ON_HAND_QTY) = '1' or (r.ALLOCATED_QTY/p.CONVERSION_QTY) > '0.25') then 'Aisle Master'
	when (li.ON_HAND_QTY-li.ALLOCATED_QTY)=0 or (r.ALLOCATED_QTY/p.CONVERSION_QTY) > 0.25 then 'Aisle Master'
    else 'Cherry Picker'
end
from REPLENISHMENT_REQUEST r
left join ITEM_UNIT_OF_MEASURE p on r.ITEM = p.ITEM and p.QUANTITY_UM = 'PL'
left join LOCATION_INVENTORY li on r.FROM_LOC = li.LOCATION
left join LOCATION l on r.TO_LOC = l.LOCATION --9.18/23
where 
isnull(r.WORK_CREATED,'N') != 'Y'
and r.USER_DEF5 is null
and isnull(r.ALLOCATED_QTY,0) != 0
and isnull(p.CONVERSION_QTY,0) != 0
and isnull(li.ON_HAND_QTY,0) != 0
END;

GO
