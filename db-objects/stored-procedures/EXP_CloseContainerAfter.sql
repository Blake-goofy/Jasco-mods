SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*
 Mod     | Programmer    | Date       | Modification Description
 --------------------------------------------------------------------
 001     | jsanders		 | 11/17/2022 | Stored Procedure for exit point:Close Container - After
 JP8	 | Blake Becker  | 03/11/2024 | Remove DOCK_AREA_ANCHOR_CRITERIA
 003	 | blash		 | 04/10/2024 | Setting REQUESTED_DELIVERY_TYPE
*/

CREATE OR ALTER PROCEDURE [dbo].[EXP_CloseContainerAfter] (
    @SESSIONVALUE xml,
    @SHIPPINGCONTAINER xml
)
AS 
    SET NOCOUNT ON; 

DECLARE @tbl TABLE(ID INT IDENTITY PRIMARY KEY,ContID XML);

INSERT INTO @tbl (ContID) values (@SHIPPINGCONTAINER);

DECLARE @CONTAINERID nvarchar(max) =
(
SELECT
    xc.value('(CONTAINER_ID)[1]', 'nvarchar(max)')
FROM
    @tbl
CROSS APPLY
    ContID.nodes('/DocumentElement/SHIPPING_CONTAINER') AS XT(XC)
)
;

BEGIN

-- JP8 START: remove dock area anchor criteria 
DECLARE @JP8_MIN_WEIGHT AS NUMERIC (19, 5);
DECLARE @JP8_DOCK_AREA AS NUMERIC (9, 0);
DECLARE @DOCK_AREA_DESC AS NVARCHAR (50);
DECLARE @PALLET_WEIGHT AS NUMERIC (19, 5);

-- Process history variables
DECLARE @stProcess AS NVARCHAR(50) = N'JP8_MinWeightStageRedirect',
        @stAction AS NVARCHAR(50),
        @stIdentifier1 AS NVARCHAR(200),
        @stIdentifier2 AS NVARCHAR(200),
        @stIdentifier3 AS NVARCHAR(200),
        @stIdentifier4 AS NVARCHAR(200),
        @stMessage AS NVARCHAR(500),
        @stProcessStamp AS NVARCHAR(100) = N'EXP_CloseContainerAfter',
        @stUserName AS NVARCHAR(30) = SUSER_SNAME(),
        @stWarehouse AS NVARCHAR(25),
        @cProcHistActive AS NVARCHAR(2) = NULL;

SELECT @JP8_MIN_WEIGHT = TRY_CONVERT (NUMERIC (19, 5), SYSTEM_VALUE)
FROM SYSTEM_CONFIG_DETAIL
WHERE RECORD_TYPE = N'Technical'
      AND SYS_KEY = N'JP8_MIN_WEIGHT';

SELECT @JP8_DOCK_AREA = TRY_CONVERT (NUMERIC (9, 0), SYSTEM_VALUE)
FROM SYSTEM_CONFIG_DETAIL
WHERE RECORD_TYPE = N'Technical'
      AND SYS_KEY = N'JP8_DOCK_AREA';

SELECT @DOCK_AREA_DESC = DESCRIPTION -- Use for audit log
FROM FILTER_CONFIG_DETAIL
WHERE OBJECT_ID = @JP8_DOCK_AREA;

IF @JP8_MIN_WEIGHT IS NULL OR @JP8_DOCK_AREA IS NULL
BEGIN
    -- LOG AUDIT
    DECLARE @ErrorMessage NVARCHAR(4000) = N'The JP8 technical values are not set up properly. Missing values: ';
    
    IF @JP8_MIN_WEIGHT IS NULL
        SET @ErrorMessage = @ErrorMessage + N'JP8_MIN_WEIGHT ';
    
    IF @JP8_DOCK_AREA IS NULL
        SET @ErrorMessage = @ErrorMessage + N'JP8_DOCK_AREA ';
    
    EXEC ADT_LogAudit 
        'EXP_CloseContainerAfter',              -- procName
        -1,                                      -- returnValue
        @ErrorMessage,                           -- message
        'Container: ', @CONTAINERID,             -- parm1
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

SELECT @PALLET_WEIGHT = sc.WEIGHT
FROM SHIPPING_CONTAINER AS sc
WHERE sc.CONTAINER_ID = @CONTAINERID
      AND sc.CONTAINER_CLASS = 'Pallet';

IF @PALLET_WEIGHT IS NOT NULL
   AND @JP8_MIN_WEIGHT IS NOT NULL
   AND @PALLET_WEIGHT < @JP8_MIN_WEIGHT
    BEGIN
        -- LOG PROCESS HIST
        DECLARE @LocationsAffected INT;
        
        UPDATE l
        SET l.USER_DEF1                 = l.DOCK_AREA_ANCHOR_CRITERIA,  -- temporarily stored to be returned in EXP_WorkCreationBefore
            l.DOCK_AREA_ANCHOR_CRITERIA = NULL,
            l.PROCESS_STAMP             = 'EXP_CloseContainerAfter',
            l.USER_STAMP                = SUSER_SNAME(),
            l.DATE_TIME_STAMP           = GETDATE()
        FROM LOCATION AS l
             INNER JOIN
             FILTER_CONFIG_DETAIL AS f
             ON CONVERT (NVARCHAR, f.OBJECT_ID) = l.DOCK_AREA_ANCHOR_CRITERIA
        WHERE f.DESCRIPTION = 'Pallet Flow';
        
        SET @LocationsAffected = @@ROWCOUNT;
        
        IF @LocationsAffected > 0
        BEGIN
            SET @stAction = N'150'; -- Information
            SET @stIdentifier1 = @CONTAINERID;
            SET @stIdentifier2 = CONVERT(NVARCHAR(200), @PALLET_WEIGHT);
            SET @stMessage = N'Pallet under minimum weight was closed, removing dock area anchor criteria from ' 
                           + CONVERT(NVARCHAR(10), @LocationsAffected) 
                           + N' locations with ' + ISNULL(@DOCK_AREA_DESC, N'NULL') + N'.';
            
            EXEC HIST_SaveProcHist @stProcess, @stAction, @stIdentifier1, @stIdentifier2, @stIdentifier3, 
                                   @stIdentifier4, @stMessage, @stProcessStamp, @stUserName, @stWarehouse, @cProcHistActive;
        END
    END
-- JP8 END

--Step 2: Correct weight
if exists (select 1 from SHIPPING_CONTAINER where PARENT_CONTAINER_ID = @CONTAINERID and WEIGHT > 99999)
begin

	update c set c.WEIGHT = (u.WEIGHT*c.QUANTITY) from SHIPPING_CONTAINER c inner join ITEM_UNIT_OF_MEASURE u on c.ITEM = u.ITEM and u.QUANTITY_UM = 'EA' where c.PARENT_CONTAINER_ID = @CONTAINERID;
	declare @totalWeight numeric(9,5) = (select sum(sc.QUANTITY * u.WEIGHT) from SHIPPING_CONTAINER sc inner join ITEM_UNIT_OF_MEASURE u on sc.ITEM=u.ITEM and u.QUANTITY_UM='EA' where sc.PARENT_CONTAINER_ID = @CONTAINERID);
	update c set c.WEIGHT = (@totalWeight+ct.EMPTY_WEIGHT) from SHIPPING_CONTAINER c inner join CONTAINER_TYPE ct on c.CONTAINER_TYPE = ct.CONTAINER_TYPE where c.CONTAINER_ID = @CONTAINERID;

end

--Step 3: set REQUESTED_DELIVERY_TYPE
if object_id(N'tempdb.dbo.#type') is not null drop table #type;
select
sh.SHIPMENT_ID
,sh.INTERNAL_SHIPMENT_NUM
,sh.REQUESTED_DELIVERY_DATE
,sh.REQUESTED_DELIVERY_TYPE
,NEW_TYPE =
case
	when sh.REQUESTED_DELIVERY_DATE is null then NULL
	when convert(date, sh.REQUESTED_DELIVERY_DATE) = convert(date, getdate()) then 'On' 
	when convert(date, sh.REQUESTED_DELIVERY_DATE) > convert(date, getdate()) then 'By' 
	else 'After'
end
into #type
from
SHIPMENT_HEADER sh
inner join SHIPPING_CONTAINER sc on sc.INTERNAL_SHIPMENT_NUM = sh.INTERNAL_SHIPMENT_NUM
where
sc.CONTAINER_ID = @CONTAINERID
and sh.CARRIER_TYPE = 'Parcel'

if exists (select top 1 'X' from #type t where isnull(t.REQUESTED_DELIVERY_TYPE,'N') != isnull(t.NEW_TYPE,'N'))
begin
	update sh set
	sh.REQUESTED_DELIVERY_TYPE = t.NEW_TYPE
	,sh.DATE_TIME_STAMP = getdate()
	,sh.PROCESS_STAMP = 'EXP_CloseContainerAfter'
	,sh.USER_STAMP = 'blash'
	from
	SHIPMENT_HEADER sh
	inner join (select distinct t.INTERNAL_SHIPMENT_NUM, t.NEW_TYPE, t.REQUESTED_DELIVERY_TYPE from #type t) t on t.INTERNAL_SHIPMENT_NUM = sh.INTERNAL_SHIPMENT_NUM
	where isnull(t.REQUESTED_DELIVERY_TYPE,'N') != isnull(t.NEW_TYPE,'N')
end

END--end proc
GO
