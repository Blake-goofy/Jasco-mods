/*
 Mod     | Programmer    | Date       | Modification Description
 --------------------------------------------------------------------
 001     | Blake Becker  | 01/07/2025 | Created.
*/

CREATE PROC JP2_ODWS_AllocationRequestModify @LAUNCH_NUM NUMERIC (9,0) AS

/*
 Change PL to CS before container creation so that a case labels can be generated.
 We use a generic config list of the customers who need CS labels.
 We also flag CUSTOMER_CATEGORY7 to use in VAS criteria so the team knows to apply labels.
*/

DECLARE @CATEGORY NVARCHAR(50) = N'JP2_CSLBL'

-- Process history variables
DECLARE @stProcess AS NVARCHAR(50) = N'JP2_AllocationRequestModify',
        @stAction AS NVARCHAR(50),
        @stIdentifier1 AS NVARCHAR(200),
        @stIdentifier2 AS NVARCHAR(200),
        @stIdentifier3 AS NVARCHAR(200),
        @stIdentifier4 AS NVARCHAR(200),
        @stMessage AS NVARCHAR(500),
        @stProcessStamp AS NVARCHAR(100) = N'JP2_ODWS_AllocationRequestModify',
        @stUserName AS NVARCHAR(30) = SUSER_SNAME(),
        @stWarehouse AS NVARCHAR(25),
        @cProcHistActive AS NVARCHAR(2) = NULL;

SELECT @stWarehouse = warehouse FROM SHIPMENT_HEADER WHERE LAUNCH_NUM = @LAUNCH_NUM

-- Check if @CATEGORY is active
IF NOT EXISTS (SELECT 1
               FROM GENERIC_CONFIG_DETAIL
               WHERE RECORD_TYPE = N'CUSTOMER_CAT7'
                     AND IDENTIFIER = @CATEGORY
                     AND ACTIVE = N'Y')
BEGIN
    SET @stAction = N'330'; -- Warning
    SET @stIdentifier1 = CONVERT(NVARCHAR(200), @LAUNCH_NUM);
    SET @stMessage = N'Category ' + @CATEGORY + N' is not active in GENERIC_CONFIG_DETAIL. PL to CS conversion skipped.';
    EXEC HIST_SaveProcHist @stProcess, @stAction, @stIdentifier1, @stIdentifier2, @stIdentifier3, @stIdentifier4, @stMessage, @stProcessStamp, @stUserName, @stWarehouse, @cProcHistActive;
    RETURN;
END

BEGIN TRY
    UPDATE SHIPMENT_HEADER
    SET CUSTOMER_CATEGORY7 = @CATEGORY, -- This flag is used for VAS criteria.
        PROCESS_STAMP      = @stProcessStamp,
        DATE_TIME_STAMP    = GETUTCDATE(),
        USER_STAMP         = @stUserName
    WHERE LAUNCH_NUM = @LAUNCH_NUM
          AND EXISTS (SELECT 1  -- Only affect customers on this list
                      FROM GENERIC_CONFIG_DETAIL
                      WHERE IDENTIFIER = SHIPMENT_HEADER.CUSTOMER
                            AND ACTIVE = N'Y')
          AND EXISTS (SELECT 1 -- Only apply if this @CATEGORY is active
                      FROM GENERIC_CONFIG_DETAIL
                      WHERE RECORD_TYPE = N'CUSTOMER_CAT7'
                            AND IDENTIFIER = @CATEGORY
                            AND ACTIVE = N'Y');

    UPDATE SHIPMENT_ALLOC_REQUEST
    SET CONVERTED_QTY_UM    = N'CS',
        CONVERTED_ALLOC_QTY = ALLOCATED_QTY / UOM.CONVERSION_QTY,
        ITEM_WEIGHT         = UOM.WEIGHT,
        ITEM_LENGTH         = UOM.LENGTH,
        ITEM_HEIGHT         = UOM.HEIGHT,
        ITEM_WIDTH          = UOM.WIDTH,
        CONTAINER_WEIGHT    = UOM.WEIGHT,
        CONTAINER_LENGTH    = UOM.LENGTH,
        CONTAINER_HEIGHT    = UOM.HEIGHT,
        CONTAINER_WIDTH     = UOM.WIDTH,
        USER_DEF1           = N'PL',
        PROCESS_STAMP       = @stProcessStamp,
        DATE_TIME_STAMP     = GETUTCDATE(),
        USER_STAMP          = @stUserName
    FROM ITEM_UNIT_OF_MEASURE AS UOM
    WHERE SHIPMENT_ALLOC_REQUEST.LAUNCH_NUM = @LAUNCH_NUM
          AND UOM.ITEM = SHIPMENT_ALLOC_REQUEST.ITEM
          AND UOM.QUANTITY_UM = N'CS'
          AND SHIPMENT_ALLOC_REQUEST.CONVERTED_QTY_UM = N'PL'
          AND EXISTS (SELECT 1 -- Was flagged in prior UPDATE
                      FROM SHIPMENT_HEADER AS SH
                      WHERE SH.INTERNAL_SHIPMENT_NUM = SHIPMENT_ALLOC_REQUEST.INTERNAL_SHIPMENT_NUM
                            AND SH.CUSTOMER_CATEGORY7 = @CATEGORY);

    -- Log success for PL to CS conversions
    DECLARE @RowsConverted INT = @@ROWCOUNT;

    IF @RowsConverted > 0
    BEGIN
        SET @stAction = N'300'; -- Success
        SET @stIdentifier1 = CONVERT(NVARCHAR(200), @LAUNCH_NUM);
        SET @stMessage = CONVERT(NVARCHAR(50), @RowsConverted) + N' PL allocations converted to CS allocations successfully.';
        EXECUTE HIST_SaveProcHist @stProcess, @stAction, @stIdentifier1, @stIdentifier2, @stIdentifier3, @stIdentifier4, @stMessage, @stProcessStamp, @stUserName, @stWarehouse, @cProcHistActive;
    END
END TRY
BEGIN CATCH
    DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
    DECLARE @ErrorNumber INT = ERROR_NUMBER();
    DECLARE @ErrorSeverity INT = ERROR_SEVERITY();
    DECLARE @ErrorState INT = ERROR_STATE();

    -- Log error in audit
    EXEC ADT_LogAudit 
        'JP2_ODWS_AllocationRequestModify',     -- procName
        -1,                                      -- returnValue
        @ErrorMessage,                           -- message
        'Launch: ', @LAUNCH_NUM,                -- parm1
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
        @stWarehouse;                            -- warehouse

    -- Re-throw the error
    THROW;
END CATCH

-- Check for items missing CS unit of measure and log warning if found
DECLARE @MissingCSItemsTable TABLE (ITEM NVARCHAR(100));

INSERT INTO @MissingCSItemsTable (ITEM)
SELECT DISTINCT SAR.ITEM
FROM SHIPMENT_ALLOC_REQUEST AS SAR
WHERE SAR.LAUNCH_NUM = @LAUNCH_NUM
      AND SAR.CONVERTED_QTY_UM = N'PL'
      AND EXISTS (SELECT 1 -- Was flagged in prior UPDATE
                  FROM SHIPMENT_HEADER AS SH
                  WHERE SH.INTERNAL_SHIPMENT_NUM = SAR.INTERNAL_SHIPMENT_NUM
                        AND SH.CUSTOMER_CATEGORY7 = @CATEGORY)
      AND NOT EXISTS (SELECT 1 -- Missing CS unit of measure
                      FROM ITEM_UNIT_OF_MEASURE AS UOM
                      WHERE UOM.ITEM = SAR.ITEM
                            AND UOM.QUANTITY_UM = N'CS');

IF EXISTS (SELECT 1 FROM @MissingCSItemsTable)
BEGIN
    DECLARE @MissingCSItems NVARCHAR(500);
    
    SELECT @MissingCSItems = STRING_AGG(ITEM, ', ')
    FROM @MissingCSItemsTable;
    
    SET @stAction = N'330'; -- Warning
    SET @stIdentifier1 = CONVERT(NVARCHAR(200), @LAUNCH_NUM);
    SET @stMessage = N'CS unit of measure does not exist for items: ' + @MissingCSItems + N'. PL to CS conversion skipped for these items.';
    EXEC HIST_SaveProcHist @stProcess, @stAction, @stIdentifier1, @stIdentifier2, @stIdentifier3, @stIdentifier4, @stMessage, @stProcessStamp, @stUserName, @stWarehouse, @cProcHistActive;
END