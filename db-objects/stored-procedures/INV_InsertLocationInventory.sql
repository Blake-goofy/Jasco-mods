SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*
	Mod Number	| Programmer	| Date   	| Modification Description
	--------------------------------------------------------------------
	9593		| RAB			| 08/15/02	| Created.
	11870		| TBS			| 09/16/03	| Added Multi-Byte support.
	10684		| LJM			| 11/03/03	| Support lot-controlled permanent locations
	14842		| RAB			| 09/17/04	| Returned identity.
	16780		| TDL			| 09/07/05	| Force Recompile
	19167		| SAT			| 05/05/06	| License Plate change
	47847		| PP			| 03/03/09	| Modified Volume and Weight datatype to Numeric - 28,5 from Numeric - 19,5.
	66433		| SSH			| 07/03/10	| Added parameter @locInvAttributeId.
	82175		| DRK			| 04/13/2011| Fixed Inv Status in Xn History for Inv Mgmt
	86637       | MDL			| 07/19/11  | Return error message if allocation result into -ve available for only inventory location class.
	101024      | MMM			| 05/30/13  | Added validation to prevent multiple item insertion in single item location due to concurrency issue.
	132035		| SAM			| 11/08/13	| Added @stReferenceType as the parameter and skipped single item validation in case of slotting
	242002		| PS			| 17/11/19	| Modified to fetch Volume_UM and WEIGHT_UM from item unit of measure.
	JP3			| Blake Becker	| 08/02/2024| Using "dead" USER_DEF1 to insert new inventory for DECANT
	Inserts a new LocationInventory record based on the to side
	of the current adjustment.
	
	Parameters
		Adjustment information.
		Information off of the  Inventory record.
		
	Output parameters
		The number of rows inserted.
*/

-- #DEFINE WMW.JSharp.General com.pronto.general.Constants Constants;

CREATE OR ALTER   PROCEDURE [dbo].[INV_InsertLocationInventory](
	@cAllocEffect nchar(1), -- SYSTEM_CREATED used to set char type
	@cInTransEffect nchar(1), -- SYSTEM_CREATED used to set char type
	@cOnHandEffect nchar(1), -- SYSTEM_CREATED used to set char type
	@cSuspEffect nchar(1), -- SYSTEM_CREATED used to set char type
	@dOverrodeVolumePerItem numeric(28,5),
	@dOverrodeWeightPerItem numeric(28,5),
	@dQuantity numeric(19,5),
	@dtExpDate datetime,
	@dtManDate datetime,
	@stCompany nvarchar(25),
	@stInventorySts nvarchar(50) output,
	@stItem nvarchar(50),
	@stItemDesc nvarchar(100),
	@stLot nvarchar(25),
	@stQuantityUm nvarchar(25),
	@stToLoc nvarchar(25),
	@logisticsUnit nvarchar(50),
	@parentLogisticsUnit nvarchar(50),
	@stToWhs nvarchar(25),
	@stUserName nvarchar(30),
	@dtFromAgingDate datetime,
	@dtFromExpDate datetime,
	@dtFromManDate datetime,
	@dtFromRecDate datetime,
	@stFromInvSts nvarchar(50),
	@stFromItemColor nvarchar(25),
	@stFromItemDesc nvarchar(100),
	@stFromItemSize nvarchar(25),
	@stFromItemStyle nvarchar(25),
	@cPermanent nchar(1),
	@stUserDef1 nvarchar(25),
	@stUserDef2 nvarchar(25),
	@stUserDef3 nvarchar(25),
	@stUserDef4 nvarchar(25),
	@stUserDef5 nvarchar(25),
	@stUserDef6 nvarchar(25),
	@dUserDef7 numeric(19,5),
	@dUserDef8 numeric(19,5),
    @locInvAttributeId numeric(9) = NULL,
	@stReferenceType nvarchar(50) ,
	@fromUserdef1 nvarchar(25), -- JP3 Blake Becker 08/02/2024
	@iRowCount int output,
	@locInvNum numeric(9) output)
AS
	SET NOCOUNT ON;

	-- local variables
	declare @cOverride nchar(1);
	declare @dCostPerItem numeric(19,5);
	declare @dValuePerItem numeric(19,5);
	declare @dVolumePerItem numeric(28,5);
	declare @dWeightPerItem numeric(28,5);
	declare @stWeightUM nvarchar(25);
	declare @stVolumeUM nvarchar(25)
	declare @iError int;
	declare @stItemColor nvarchar(25);
	declare @stItemSize nvarchar(25);
	declare @stItemStyle nvarchar(25);
	declare @stLocTemplate nvarchar(25);
	declare @stTemplateField1 nvarchar(25);
	declare @stTemplateField2 nvarchar(25);
	declare @stTemplateField3 nvarchar(25);
	declare @stTemplateField4 nvarchar(25);
	declare @stTemplateField5 nvarchar(25);
	declare @locationClass nvarchar(25)
	declare @stErrorMsg nvarchar(2000);
	declare @multiItem nchar(1);
	declare @validUserdef1 nchar(1);-- JP3 Blake Becker 08/02/2024

	-- set local booleans.
	if (@dOverrodeVolumePerItem is not null
		OR @dOverrodeWeightPerItem is not null)
		set @cOverride = N'Y';

	if(@locInvAttributeId = 0)
		SET @locInvAttributeId = NULL;
	
	-- retrieve information from the Location table.
	SELECT @stLocTemplate = LOCATION_TEMPLATE,
		   @stTemplateField1 = TEMPLATE_FIELD1,
		   @stTemplateField2 = TEMPLATE_FIELD2,
		   @stTemplateField3 = TEMPLATE_FIELD3,
		   @stTemplateField4 = TEMPLATE_FIELD4,
		   @stTemplateField5 = TEMPLATE_FIELD5,
		   @locationClass =LOCATION_CLASS,
		   @multiItem = MULTI_ITEM
	  FROM LOCATION
	 WHERE LOCATION = @stToLoc
	   AND WAREHOUSE = @stToWhs;

	SET @validUserdef1 = -- JP3 Blake Becker 08/02/2024
	CASE
		WHEN @fromUserdef1 IS NULL THEN N'N' -- This is passed as NULL if from inventory record still exists
		WHEN @stTemplateField1 != N'DECANT' THEN N'N'
		ELSE N'Y'
	END

	-- if the location doesn't exist, create it and
	-- use default values.
	if (@@ROWCOUNT = 0)
	begin
		exec @iError = INV_InsertLocation @stToLoc, @stUserName, @stToWhs
		if (@@ERROR <> 0) return -1; else if (@iError <> 0) return @iError;
		set @stTemplateField1 = @stToLoc;
	end; -- end if location doesn't exist.

	-- retrieve infrormation off of the Item and ItemUnitOfMeasure tables.
	SELECT @dCostPerItem = costPerItem,
		   @dValuePerItem = valuePerItem,
		   @dVolumePerItem = volumePerItem,
		   @dWeightPerItem = weightPerItem,
		   @stWeightUM= weightUm,
		   @stVolumeUM=volumeUm,
		   @stItemColor = itemColor,
		   @stItemDesc = ISNULL(@stItemDesc, itemDesc),
		   @stItemSize = itemSize,
		   @stItemStyle = itemStyle
	  FROM dbo.INVfn_RtrvItemInfo(@stItem, @stCompany, @stQuantityUm, 
								  @stToLoc, @stToWhs, @cOverride);

	-- Set the Inventory Status to be set in the Transaction History
	if (@stInventorySts is null)
		set @stInventorySts = @stFromInvSts;

	-- if this allocation result into -ve inventory then do not allow that
	-- assume that there are no scenarios where we increase both onhand/intransit with allocate bucket 
	-- that why not considering other effect with alloceffect.
			If(@locationClass = N'Inventory' AND @cAllocEffect = N'+'  AND @dQuantity > 0) 
	     	begin
						
			    set @stErrorMsg = N'MSG_INVVAL10: ' + dbo.RSCMfn_RtrvMsg(N'MSG_INVVAL10'); 		
				RAISERROR(@stErrorMsg , 18, 1);
				return -1;   
			End;
			
	if (@multiItem = N'N' 
		and @locationClass=N'Inventory' 
		and (@cInTransEffect = N'+' or @cOnHandEffect = N'+' )
		and @dQuantity > 0
		and exists (select top 1 *
			from LOCATION_INVENTORY
			where LOCATION = @stToLoc
			and warehouse = @stToWhs
			and ITEM <> @stItem
			and ((PERMANENT = N'N' and ON_HAND_QTY > 0) or PERMANENT = N'Y') ))
	begin
		--Slotting adjust type is not expected to be used for other adjustments.
		if NOT EXISTS(SELECT TOP 1 SYSTEM_VALUE from SYSTEM_CONFIG_DETAIL
							WHERE  SYS_KEY=N'70' AND RECORD_TYPE = N'SLOT'
							AND SYSTEM_VALUE = @stReferenceType)
			BEGIN
				set @stErrorMsg = N'MSG_INVVAL13: ' + dbo.RSCMfn_RtrvMsg(N'MSG_INVVAL13'); 		
				RAISERROR(@stErrorMsg , 18, 1);
				return -1; 
			END
	end
		
	-- insert the LocationInventory record.
	INSERT INTO LOCATION_INVENTORY
		   (LOCATION,
		    WAREHOUSE,
		    ITEM,
		    COMPANY,
		    LOT,
		    PERMANENT,
		    ON_HAND_QTY,
		    IN_TRANSIT_QTY,
		    ALLOCATED_QTY,
		    SUSPENSE_QTY,
		    QUANTITY_UM,
		    INVENTORY_STS,
		    ITEM_DESC,
		    AGING_DATE,
		    RECEIVED_DATE,
		    MANUFACTURED_DATE,
		    EXPIRATION_DATE,
		    TEMPLATE_FIELD1,
		    TEMPLATE_FIELD2,
		    TEMPLATE_FIELD3,
		    TEMPLATE_FIELD4,
		    TEMPLATE_FIELD5,
		    LOCATION_TEMPLATE,
		    ITEM_COLOR,
		    ITEM_SIZE,
		    ITEM_STYLE,
		    TOTAL_COST,
		    TOTAL_VALUE,
		    TOTAL_VOLUME,
		    TOTAL_WEIGHT,
			WEIGHT_UM,
			VOLUME_UM,
		    PROCESS_STAMP,
		    USER_STAMP,
		    DATE_TIME_STAMP,
		    LOC_INV_ATTRIBUTES_ID,
		    LOGISTICS_UNIT,
		    PARENT_LOGISTICS_UNIT,
		    USER_DEF1,
		    USER_DEF2,
		    USER_DEF3,
		    USER_DEF4,
		    USER_DEF5,
		    USER_DEF6,
		    USER_DEF7,
		    USER_DEF8)
	VALUES (@stToLoc,
			@stToWhs,
			@stItem,
			@stCompany,
			@stLot,
			CASE WHEN @cPermanent IS NULL THEN N'N' ELSE @cPermanent END, -- permanent
			CASE WHEN @cOnHandEffect = N'+' THEN @dQuantity
				 ELSE 0.0 END, -- onHandQty
			CASE WHEN @cInTransEffect = N'+' THEN @dQuantity
				 ELSE 0.0 END, -- inTransitQty
			CASE WHEN @cAllocEffect = N'+' THEN @dQuantity
				 ELSE 0.0 END, -- allocatedQty
			CASE WHEN @cSuspEffect = N'+' THEN @dQuantity
				 ELSE 0.0 END, -- suspenseQty		   
		    @stQuantityUm,
			CASE -- if a value was passed in, use it.
				 WHEN @stInventorySts is not null
				 THEN @stInventorySts
				 -- otherwise, use the from value.
				 ELSE @stFromInvSts
				 END, -- inventorySts
			CASE -- if from value exists, use it.
				 WHEN @stFromItemDesc is not null
				 THEN @stFromItemDesc
				 -- otherwise, use the specified value.
				 ELSE @stItemDesc
				 END, -- itemDesc
			CASE -- if from value exists, use it.
				 WHEN @dtFromAgingDate is not null
				 THEN @dtFromAgingDate
				 -- otherwise, set to current datetime.
				 ELSE GETUTCDATE()
				 END, -- agingDate
			CASE -- if blank and from value exists, use it.
				 WHEN @dtFromRecDate is not null
				 THEN @dtFromRecDate
				 -- otherwise, set to current datetime.
				 ELSE GETUTCDATE()
				 END, -- receivedDate
			CASE -- if from value exists, use it.
				 WHEN @dtFromManDate is not null
				 THEN @dtFromManDate
				 -- otherwise, use the specified value.
				 ELSE @dtManDate
				 END, -- manufacturedDate
			CASE -- if not lot controlled, use the max time.
				 WHEN @stLot is null
				 THEN dbo.DHfn_TransToSQLDate(N'47121231000000')
				 -- if lot controlled and from value exists, use it.
				 WHEN @dtFromExpDate is not null
				 THEN @dtFromExpDate
				 -- otherwise, use the specified value.
				 ELSE @dtExpDate
				 END, -- expirationDate
			@stTemplateField1,
			@stTemplateField2,
			@stTemplateField3,
			@stTemplateField4,
			@stTemplateField5,
			@stLocTemplate,
			CASE -- if from value exists, use it.
				 WHEN @stFromItemColor is not null
				 THEN @stFromItemColor
				 -- otherwise, use the retrieved value.
				 ELSE @stItemColor
				 END, -- itemColor
			CASE -- if from value exists, use it.
				 WHEN @stFromItemSize is not null
				 THEN @stFromItemSize
				 -- otherwise, use the retrieved value.
				 ELSE @stItemSize
				 END, -- itemSize
			CASE -- if from value exists, use it.
				 WHEN @stFromItemStyle is not null
				 THEN @stFromItemStyle
				 -- otherwise, use the retrieved value.
				 ELSE @stItemStyle
				 END, -- itemStyle
			CASE WHEN @cOnHandEffect = N'+'
				 THEN @dCostPerItem * @dQuantity
				 ELSE 0.0
				 END, -- totalCost
			CASE WHEN @cOnHandEffect = N'+'
				 THEN @dValuePerItem * @dQuantity
				 ELSE 0.0
				 END, -- totalValue
				 
			-- totalVolume and weight may be overridden.
			CASE WHEN @cOnHandEffect = N'+'
					  AND @cOverride is not null
				 THEN @dOverrodeVolumePerItem * @dQuantity
				 WHEN @cOnHandEffect = N'+'
				 THEN @dVolumePerItem * @dQuantity
				 ELSE 0.0
				 END, -- totalVolume
			CASE WHEN @cOnHandEffect = N'+'
					  AND @cOverride is not null
				 THEN @dOverrodeWeightPerItem * @dQuantity
				 WHEN @cOnHandEffect = N'+'
				 THEN @dWeightPerItem * @dQuantity
				 ELSE 0.0
				 END, -- totalWeight
				 @stWeightUM,
				 @stVolumeUM,
		   N'INV_InsertLocationInventory', -- process stamp
		   @stUserName,
		   GETUTCDATE(),-- dateTimeStamp
		   @locInvAttributeId,
		   @logisticsUnit,
		   @parentLogisticsUnit,
		   CASE WHEN @validUserdef1 = N'Y' THEN @fromUserdef1 ELSE @stUserDef1 END, -- JP3 Blake Becker 08/02/2024
		   @stUserDef2,
		   @stUserDef3,
		   @stUserDef4,
		   @stUserDef5,
		   @stUserDef6,
		   @dUserDef7,
		   @dUserDef8); 
	SELECT @iError = @@ERROR, @iRowCount = @@ROWCOUNT, @locInvNum = @@IDENTITY;
	return @iError;
-- end INV_InsertLocationInventory



GO
