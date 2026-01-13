SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*
	Mod Number	| Programmer	| Date   	| Modification Description
	--------------------------------------------------------------------
	9593		| RAB			| 08/14/02	| Created.
	9493		| PK			| 01/31/03	| Real Time Replenishment.
	4415		| RAB			| 03/05/03	| Add userDef fields.
	10790		| RAB			| 03/20/03	| Add forceOnHandZero.
	10753		| RAB			| 03/24/03	| Added key to returned error.
	10861		| TDA			| 04/02/03	| Remove initialization of stInitInvSts
	11191		| RAB			| 04/29/03	| Pass forceOnHandZero to INV_SaveHistInvChg.
	9493		| PK			| 04/23/03	| Fix the ILC UM conversion during INV Adjust
	11247		| RLE			| 05/12/03	| throw error when container tracked and user did not specify container
	11870		| TBS			| 09/16/03	| Added Multi-Byte support.
	10684		| LJM			| 11/03/03	| Support lot-controlled permanent locations
	14473		| TDL			| 04/13/04	| Fixed Apostrophes
	14714		| MD			| 06/16/04	| Fixed non deletion Lot-controlled permanent location
	14842		| RAB			| 09/09/04	| Added argumentGroupId.
	14972		| LJM			| 09/20/04	| delete serial numbers when location inventory deleted
	15433		| LJM			| 10/13/04	| do not log negative inventory audit
	15154		| SM			| 08/04/05	| Fixed Variable Casing
	16413       | KSP           | 04/20/05  | Expanded Lot Control
	16820       | RR	        | 07/28/05  | Passed toCompany & toWhs to INV_SaveHistInvChg
	19167		| SAT			| 05/05/06	| License Plate change
	19166		| KSP			| 05/23/06	| License Plate Tracking
	19337		| RLG			| 12/14/06	| Replaced single quotes for toWhs
	Puts into a Location.
	20457		| PP			| 01/11/07	| Modified dtFromExpdate to have correct expiration date while performing 
											| inventory adjustment.
	12881       |KBR			|11/05/07	| Set default inventory status if inventory status is empty
	17321		| CH			|15/01/08   | insert into Location_Inventory if the status of the inventory to be updated is differenet than 
												the status of the inventory present in that location and also 
												if all the buckets are not 0 else update it.
	20631		| SMS			|02/29/08	| Added logic to update AGING_DATE and RECEIVED_DATE based on TO LOCATION information.
	22534		| SMS			| 03/28/08	| Added functionality for consolidation during locate
											  when Item UM override is done
	23832		| MDL			| 04/14/08	| Fixed for Oracle issue 
	19244		| BTA			| 04/28/08	| Fixed another Oracle issue.
	28856		| SSH			| 07/09/08	| Fixed occurrence of extra UM records. 
	31865		| SSH			| 07/28/08	| Fixed for Oracle issue.
	33174		| DRK			| 08/18/08	| Aging Date is prevented from being updated based on 
												ToLocation Aging Date
	33159       | AK            | 08/28/08  | Modified the clause for INTERNAL_CONTAINER_NUM											
	36750       | AK            | 09/24/08  | Fixed the warehouse transfer to copy the LOCATION_UNIT_OF_MEASURES during the transfer.										
	39788       | AK            | 11/05/08  | Added logic such that All inventory adjusted at, transferred to, or putaway to a shipping location 
	                                        | will be set to the Default inventory status for adjustments Inventory Control Value
	40960		| DSK			| 11/18/08	| Passed ToWarehouse value to the INV_SaveHistInvChg	     
	41290		| KRG			| 11/20/08	| Prevented duplicate Location UMs while receipt check-in                                  
	39788       | AK            | 11/05/08  | The system must support only one status at the packing/staging location.
	                                        | It should take the status of the inventory that gets into the location first.
	48752		| DRK			| 03/23/09	| Prevented Updation of Received Date and Aging Date when
												Transaction Type is Inventory Transfer
											  Fixed ORACLE errors
	50254		| DRK			| 04/28/09	| Prevented LUM from being copied to Shipping Dock
												and Put to Store Locations
	52336		| SVS			| 05/22/09	| Set inventory status correctly in transaction history.					
	59605		| RAB			| 10/19/09	| Do not create additional LocationInventory records on inventory status mismatch in the pre-receiving class.
	63602		| DSK			| 01/06/10	| For Inventory transfer create/Update Location override records for To Location only if it is empty
	63124		| DSK			| 02/04/10	| Set Internal Container Number to NULL for non Receiving Dock Locations to avoid duplicate records
	66433		| SSH			| 07/03/10	| Added parameter @toLocInvAttributeId.
	66621		| NB			| 03/24/10	| Modified to adjust the suspense qty 
	67941		| DSK			| 04/07/10	| Modified location inventory attribute logic to consider permanent locations
	69563		| TDA			| 05/20/10	| Fixed copying of location UM records for multi-item locations single item locations with the item without overrides
	70073		| SSH			| 05/26/10	| Passed parameter @toLocInvAttributeId to INV_SaveHistInvChg.

	70383		| NB			| 06/02/10	| Reverted back the change done for 66621	
	72073		| DSK			| 07/09/10	| Set Y for Permanent locations with location inventory attributes
	72335		| MDL			| 07/26/10	| Delete location UM override in case of automatic putaway   	
	71121		| SPJ			| 07/26/10	| For Inventory Transfer Update ToLocation UM with fromLocation UM for all the LPs present in destination location if its a LP tracked Location.
	74373	| OM	| 09/08/10 | Fixed new row being inserted for PTS location if the inventory status did not match
	76856	| SSC	| 11/04/10 | Removed check for empty location status 
	76867		| SPJ			| 11/09/10	| Modified to update LUM records when toLocation is Receiving Dock and LUM exists for the item and company combination.
	76933		| SSC			| 11/16/10	| Fixed issue with transaction history logging with attributes incase location is empty
	74578		| RK			| 12/01/10	| Modified to Merge the inventory statuses at P&D location for shipment work if the P&D is non-lp tracked
	78074		| DSK			| 12/10/10	| Fixed the permanent location issue to consider the empty location to have inventory the attribute value
	78968		| RJR			| 02/10/11	| Fixed duplicate inventory attribute ID when partial picking to LP tracked location. 
	82428		| RJR			| 03/22/11	| Fixed bug where system was adjusting new inventory attribute record onto an existing inventory record with different attribute values (which it should not be). 
	82430		| RJR			| 03/22/11	| Also compare attribute values when determine ID that should be used at to location. 
	82175		| DRK			| 04/13/2011| Fixed Inv Status in Xn History for Inv Mgmt
	83531		| MDL			| 04/26/11	| Keep lot into account while looking for deleting location UM override. 
	83531		| MDL			| 04/26/11	| Do not consider record date time when checking for distinct record. 
	86637       | MDL			| 07/19/11  | Return error message if allocation result into -ve available for only inventory location class.
	88493		| MDL		    | 09/01/11	| Modify to handle the LUOM for override location correctly .
	93922		| DN			| 02/02/12	| quotes for transtype
	94517		| MMM			| 02/14/12	| Implemented Mutex lock(sp_getapplock) to avoid duplicate inventory record insertion
	99576		| SAM			| 05/21/12	| added logic to handle negative intransitquantity 
	100514		| MMM			| 06/21/12	| Corrected logic to set new expiration date on location inventory record for Warehouse Transfer/Inventory Transfer transaction types
	101024      | MMM			| 05/30/13  | Extended mutex lock to location level instead of unique inventory record level for single item location 
											  to avoid multiple item insertion at the same location(concurrency issue).
	132035		| SAM			| 11/08/13	| Passed @stReferenceType to INV_InsertLocationInventory
	167534      | KSS           | 10/07/15  | modified  logic to calculate available qty.
	178231		| SHS			| 05/19/16	| Excluded Replenishment allocation while updating aging date
	184053		| MMM			| 08/02/16	| Modified @toLocInvAttributeId to output parameter - acts as both input/output parameter 
	213282		| NRJ			| 09/22/17	| Modified to remove release of app lock and acquired lock on unique location inventory record to avoid deadlocks.
	214624      | KSS           | 11/15/17  | Modified cpde to set the after exp date
	JP3	        | Blake Becker  | 08/02/2024| Passing USER_DEF1 to INV_InsertLocationInventory
	Parameters
		Adjustment information.
		From LocationInventory values.	
*/

-- #DEFINE WMW.JSharp.General com.pronto.general.Constants Constants;

CREATE OR ALTER   PROCEDURE [dbo].[INV_PutIntoLocation](
	@cForceOnHandZero nchar(1), -- SYSTEM_CREATED used to set char type
	@cReversal nchar(1), -- SYSTEM_CREATED used to set char type
	@cToAllocEffect nchar(1), -- SYSTEM_CREATED used to set char type
	@cToInTransEffect nchar(1), -- SYSTEM_CREATED used to set char type
	@cToOnHandEffect nchar(1), -- SYSTEM_CREATED used to set char type
	@cToSuspEffect nchar(1), -- SYSTEM_CREATED used to set char type
	@dOverrodeVolumePerItem numeric(28,5),
	@dOverrodeWeightPerItem numeric(28,5),
	@dQuantity numeric(19,5),
	@dReferenceLine numeric(19,5),
	@dtExpDate datetime,
	@dtManDate datetime,
	@iInternalNum numeric(9),
	@stCompany nvarchar(25),
	@stEquipmentType nvarchar(25),
	@stInventorySts nvarchar(50),
	@stItem nvarchar(50),
	@stItemDesc nvarchar(100),
	@stLot nvarchar(25),
	@stQuantityUM nvarchar(25),
	@stRecContID nvarchar(25),
	@stParentLogisticsUnit nvarchar(50),
	@stReferenceID nvarchar(25),
	@stReferenceType nvarchar(50),
	@stTeam nvarchar(50),
	@stToContId nvarchar(50),
	@stToLoc nvarchar(25),
	@stToWhs nvarchar(25),
	@stTransType nvarchar(50),
	@stUserDef1 nvarchar(50),
	@stUserDef2 nvarchar(50),
	@stUserDef3 nvarchar(50),
	@stUserDef4 nvarchar(50),
	@stUserDef5 nvarchar(50),
	@stUserDef6 nvarchar(50),
	@dUserDef7 numeric(19,5),
	@dUserDef8 numeric(19,5),
	@stUserName nvarchar(30),
	@stWorkGroup nvarchar(25),
	@stWorkType nvarchar(25),
	@stWorkUnit nvarchar(50),
	@argumentGroupId nvarchar(32),
	@dtFromAgingDate datetime,
	@dtFromExpDate datetime,
	@dtFromManDate datetime,
	@dtFromRecDate datetime,
	@stFromInvSts nvarchar(50),
	@stFromItemColor nvarchar(25),
	@stFromItemDesc nvarchar(100),
	@stFromItemSize nvarchar(25),
	@stFromItemStyle nvarchar(25),
	@cTransHistActive nvarchar(250),
	@internalLocUMs nvarchar(100),
	@fromIntLocInv numeric(9),
	@fromUserdef1 nvarchar(25), -- JP3 Blake Becker 08/02/2024
	@isNegativeAvailableAllowed bit = false,	
	@toLocInvAttributeId numeric(9) output)
AS
	SET NOCOUNT ON;
	
	-- constant that determines how many times the
	-- optimistic lock will be attepted before an error is thrown.
	declare @iOPTIMISTICLOCKFAILUREMAX int;
	declare @iDFLT_INVENTORY_STS int;
	declare @stINVENTORY nvarchar(25);
	
	set @iOPTIMISTICLOCKFAILUREMAX = 3;
	
	-- local variables
	declare @cAdjustmentCompleted nchar(1);
	declare @cEmpty nchar(1);
	declare @cPermanent nchar(1);
	declare @dInitAllocQty numeric(19,5);
	declare @dInitInTransQty numeric(19,5);
	declare @dInitOnHandQty numeric(19,5);
	declare @dInitSuspQty numeric(19,5);
	declare @dNewAllocQty numeric(19,5);
	declare @dNewInTransQty numeric(19,5);
	declare @dNewOnHandQty numeric(19,5);
	declare @dNewSuspQty numeric(19,5);
	declare @existingLocUmCount int;
	declare @iError int;
	declare @iIntLocInv numeric(9);
	declare @iNumOfLockFailures int;
	declare @iRowCount int;
	declare @stCntTrack nchar(1);
	declare @multiItem nchar(1);
	declare @stErrorMsg nvarchar(2000);
	declare @stInitInvSts nvarchar(50);
    declare @initExpDate datetime;
	declare @tempToWhs nvarchar(25);
	declare @toAgingDate datetime;	
	declare @toReceivedDate datetime;
	declare @agingDate datetime;
	declare @intContNum numeric(9);
	declare @fromLoc nvarchar(25);	
	declare @toLocLocationClass nvarchar(25);
	declare @fromLocLocationClass nvarchar(25);
	declare @toLocationStatus nvarchar(50);
	declare @HistToLocInvAttributeId numeric(9);
	declare @attrIDCount numeric(9);
	declare @allocateIntransit nchar(1)    
	declare @lockResource nvarchar(255);
	declare @lockResult int;	
	declare @newLocationInventoryRows int;
	declare @shouldCopyLUM char(1);
	declare @afterExpDateTime datetime;
	
	set @lockResult = -1;
	
	-- set history attribute id here as it can be set to 0 in some instances and will be written incorrectly in history
	set @HistToLocInvAttributeId = @toLocInvAttributeId;

		
	-- perform the update in an optimistic lock so that two 
	-- processes do not update the same inventory at exactly the
	-- same time and corrupt inventory.
	set @iNumOfLockFailures = 0;
	WHILE (@cAdjustmentCompleted is null
		   AND @iNumOfLockFailures < @iOPTIMISTICLOCKFAILUREMAX)
	begin

		-- For inventory transfers, the LUM records of the From Location
		-- should be copied only when the to location is empty
		--i.e. it should honor the error message MSG_INVVAL41 shown to the user 
		
		SET @shouldCopyLUM = N'Y';		
		
		--check if this is a container tracked location
		if (@cToOnHandEffect in (N'+',N'-')
		    AND @stToContId is null)
		begin
			SELECT @stCntTrack = TRACK_CONTAINERS
		  	FROM LOCATION
		 	WHERE LOCATION = @stToLoc
		   	AND WAREHOUSE = @stToWhs
			
			if (@stCntTrack = N'Y')
			begin
				set @stErrorMsg = N'MSG_INVENTORY09: ' + dbo.RSCMfn_RtrvMsg(N'MSG_INVENTORY09'); 				
				RAISERROR(@stErrorMsg , 18, 1);
				return -1;
			end; 
		end;

		-- Retrieve Internal Container Num for the container id
		SELECT @intContNum = INTERNAL_REC_CONT_NUM FROM RECEIPT_CONTAINER WHERE
		(CONTAINER_ID = @stRecContID OR CONTAINER_ID = @stToContId);

		--To set the expiration date in case of adjusting inventory
		set  @dtFromExpDate = 	CASE WHEN @dtFromExpDate is not null
								THEN @dtFromExpDate
								ELSE @dtExpDate
								END;
								
		SET @toAgingDate = @dtFromAgingDate;
		SET @toReceivedDate = @dtFromRecDate;
								
		--Set AGING_DATE and RECEIVED_DATE based on TO LOCATION
		IF EXISTS (SELECT 1 FROM LOCATION WHERE LOCATION = @stToLoc 
				AND WAREHOUSE = @stToWhs AND LOCATION_CLASS = N'Inventory')
		BEGIN
			-- Select Aging Date if already exists
			SELECT @agingDate = AGING_DATE 
			FROM LOCATION_INVENTORY
			WHERE LOCATION = @stToLoc
			AND WAREHOUSE = @stToWhs
			AND ITEM = @stItem
			AND ISNULL(COMPANY, N'!') = ISNULL(@stCompany, N'!')
			AND ISNULL(LOT, N'!') = ISNULL(@stLot, N'!')
			AND 
			(
				(ISNULL(LOGISTICS_UNIT, N'!') = ISNULL(@stRecContID, N'!'))
	    		OR
		   		(ISNULL(LOGISTICS_UNIT, N'!')  = ISNULL(@stToContId, N'!'))
			)
			AND 
			(
				ISNULL(LOC_INV_ATTRIBUTES_ID,0) = ISNULL(@toLocInvAttributeId,0)  					
			);

			--Assign Aging Date if exist in the location else assign current date
			--Exclude Inventory Transfer, Pick and Put confirmation, Pick confirmation, Putaway and Replenishment allocation 
			-- confirmation Transaction Types from updating the Aging and Received Dates
			IF (@stTransType != N'60' AND @stTransType != N'120' AND @stTransType != N'130' AND @stTransType != N'140' AND @stTransType != N'170')
			BEGIN
				IF (@agingDate IS NULL)
				BEGIN
					SET @toAgingDate = GETUTCDATE();
					SET @toReceivedDate = GETUTCDATE();
				END
				ELSE
				BEGIN
					SET @toAgingDate = @agingDate;				
					SET @toReceivedDate = @agingDate;
				END
			END
		END

        SELECT @toLocLocationClass = LOCATION_CLASS,
			@toLocationStatus = LOCATION_STS,
			@multiItem = MULTI_ITEM,
			@allocateIntransit = ALLOCATE_IN_TRANSIT
		  	FROM LOCATION
		 	WHERE LOCATION = @stToLoc
		   	AND WAREHOUSE = @stToWhs
	   		   	
	   	-- For inventory transfer the LUM records can be copied to the Destination location
	   	-- only if it is empty
	   	IF(@stTransType = N'60')
	   		BEGIN 
	   			SELECT @iIntLocInv = INTERNAL_LOCATION_INV
					   FROM LOCATION_INVENTORY
					   WHERE LOCATION = @stToLoc
					   AND WAREHOUSE = @stToWhs
					   AND ITEM = @stItem
					   AND ISNULL(COMPANY,N'!') = ISNULL(@stCompany,N'!')
					   AND (
		   					ISNULL(LOT,N'!') = ISNULL(@stLot,N'!')
		   					OR (LOT IS NULL AND PERMANENT = N'Y')
							)
					  
					   AND (
		   					 LOGISTICS_UNIT = @stRecContID
		   		    				OR
		   					(ISNULL(LOGISTICS_UNIT,N'!')  = ISNULL(@stToContId,N'!')
									 OR (LOGISTICS_UNIT IS NULL AND PERMANENT = N'Y'))
							)
					                 
				   SET @existingLocUmCount = (SELECT COUNT(*) 
											FROM LOCATION_UNIT_OF_MEASURE 
											WHERE INTERNAL_LOCATION_INV = @iIntLocInv)
							
					IF (@existingLocUmCount > 0)
						BEGIN 		  
							SET @shouldCopyLUM =N'N'			
						END
			END
				 
		-- For inventory transfer with work, the LUM records should not be copied
		-- the Empty check make sure that the flag is set correctly
		IF EXISTS(SELECT 1 FROM WORK_INSTRUCTION 
				WHERE WORK_UNIT = @stWorkUnit AND INTERNAL_NUM_TYPE = N'Inventory Transfer')
			 
		BEGIN
			IF (@existingLocUmCount > 0)
				BEGIN 		  
					SET @shouldCopyLUM =N'N'			
				END
		END
		
	   -- if the to location class type is Shipping Dock or PTS location then
       -- we need to set the from location status as same as to location status
       --Some where in the flow it takes the variable @stInventorySts to set the to location status
		if 
		(
		@toLocLocationClass = N'Shipping Dock'
		or @toLocLocationClass = N'Put to Store'
		or
		(
			@toLocLocationClass =N'P&D'
			and
			EXISTS(SELECT 1 FROM LOCATION WHERE LOCATION =@stToLoc AND WAREHOUSE = @stToWhs AND TRACK_CONTAINERS =N'N')
			and
			EXISTS(SELECT 1 FROM WORK_INSTRUCTION 
							WHERE WORK_UNIT = @stWorkUnit AND INTERNAL_NUM_TYPE = N'Shipment')
		)		
		)
            begin
                    -- Get the To location inventory status
                    SELECT @stInventorySts = INVENTORY_STS
                      FROM LOCATION_INVENTORY
						 WHERE LOCATION = @stToLoc
						   AND WAREHOUSE = @stToWhs
						   AND ITEM = @stItem
						   AND ISNULL(COMPANY,N'!') = ISNULL(@stCompany,N'!')
						   AND (
		   						ISNULL(LOT,N'!') = ISNULL(@stLot,N'!')
		   						OR (LOT IS NULL AND PERMANENT = N'Y')
								)
						  
						   AND (
		   						 LOGISTICS_UNIT = @stRecContID
		   		    					OR
		   						(ISNULL(LOGISTICS_UNIT,N'!')  = ISNULL(@stToContId,N'!')
										 OR (LOGISTICS_UNIT IS NULL AND PERMANENT = N'Y'))
							);
              end;

		-- if to location is LP tracked and partial picks were done so that work instructions were split, it is possible that the 
		-- inv attr passed does not even exist for the LP anymore as a new one may have been created; check this and if it does not 
		-- exist, get the new inv att ID for the LP at the location 
		if (@stTransType != N'40' AND ISNULL(@toLocInvAttributeId, 0) > 0 AND @toLocLocationClass = N'Inventory' AND @stToContId is not null and @cToOnHandEffect = N'+')
		begin 
			declare @existingInvAttrId numeric(9);
			declare @lpSeparator nvarchar(1);
			declare @recContLikeId nvarchar(50);
			declare @toContLikeId nvarchar(50);
			select @lpSeparator = SYSTEM_VALUE from SYSTEM_CONFIG_DETAIL where RECORD_TYPE = N'Inventory' and SYS_KEY = N'200';

			-- the LP could have a suffix so we need to check for that; we know @stToContId will not be null because we checked for it above, 
			-- but we do need to check for @stRecContID
			if (@stRecContID is null)
				set @recContLikeId = @stRecContID;
			else
				set @recContLikeId = @stRecContID + @lpSeparator + N'%';
			set @toContLikeId = @stToContId + @lpSeparator + N'%';

			SELECT @existingInvAttrId = LOC_INV_ATTRIBUTES_ID
			FROM LOCATION_INVENTORY
			WHERE LOCATION = @stToLoc
			   AND WAREHOUSE = @stToWhs
			   AND ITEM = @stItem
			   AND ISNULL(COMPANY,N'!') = ISNULL(@stCompany,N'!')
			   AND (
		   			ISNULL(LOT,N'!') = ISNULL(@stLot,N'!')
		   			OR (LOT IS NULL AND PERMANENT = N'Y')
					)
		  
				AND (
		   			 LOGISTICS_UNIT LIKE @recContLikeId OR LOGISTICS_UNIT = @stRecContID
		   		    		OR
		   			(LOGISTICS_UNIT LIKE @toContLikeId OR LOGISTICS_UNIT = @stToContId 
							 OR (LOGISTICS_UNIT IS NULL AND PERMANENT = N'Y'))
				);

			if (@existingInvAttrId is not null and @toLocInvAttributeId != @existingInvAttrId)
			begin
				-- also check the inventory attribute values to make sure they are the same
				if (dbo.INVfn_AreInvAttributeValuesSame(@toLocInvAttributeId, @existingInvAttrId) = 1)
				begin
					SET @toLocInvAttributeId = @existingInvAttrId;
					-- reset inv attr id used for history as well
					SET @HistToLocInvAttributeId = @toLocInvAttributeId;
				end
			end;
		end;
		
		SET @lockResource = ISNULL(@stToLoc, N'') + ISNULL(@stToWhs, N'');
		if not(@multiItem = N'N' and @toLocLocationClass = N'Inventory')
		begin 
			SET @lockResource = @lockResource + ISNULL(@stItem, N'') + ISNULL(@stCompany, N'') + ISNULL(@stLot, N'') + ISNULL(@stToContId, N'') + CONVERT(nvarchar, ISNULL(@toLocInvAttributeId, 0)); 
		end
		exec @lockResult = sp_getapplock @Resource=@lockResource, @LockMode = N'Exclusive', @LockTimeout=-1
			
     	-- select information off of the to LocationInventory record.
		SELECT @iIntLocInv = INTERNAL_LOCATION_INV,
			   @cPermanent = PERMANENT,
			   @dInitAllocQty = ALLOCATED_QTY,
			   @dInitInTransQty = IN_TRANSIT_QTY,
			   @dInitOnHandQty = ON_HAND_QTY,
			   @dInitSuspQty = SUSPENSE_QTY,
			   @stInitInvSts = INVENTORY_STS,
 		       @initExpDate = EXPIRATION_DATE			  
		  FROM LOCATION_INVENTORY WITH (updlock)
		 WHERE LOCATION = @stToLoc
		   AND WAREHOUSE = @stToWhs
		   AND ITEM = @stItem
		   AND ISNULL(COMPANY,N'!') = ISNULL(@stCompany,N'!')
		   AND (
		   		ISNULL(LOT,N'!') = ISNULL(@stLot,N'!')
		   		OR (LOT IS NULL AND PERMANENT = N'Y')
		        )
		  
		    AND (
		   		 LOGISTICS_UNIT = @stRecContID
		   		    	OR
		   		(ISNULL(LOGISTICS_UNIT,N'!')  = ISNULL(@stToContId,N'!')
		                 OR (LOGISTICS_UNIT IS NULL AND PERMANENT = N'Y'))
			)
			AND (
				ISNULL(LOC_INV_ATTRIBUTES_ID,0) = ISNULL(@toLocInvAttributeId,0)  
						OR
					@toLocLocationClass  = N'Receiving Dock' 
					OR 
					(LOC_INV_ATTRIBUTES_ID IS NULL AND PERMANENT = N'Y' AND 
					(ALLOCATED_QTY = 0 AND IN_TRANSIT_QTY = 0 AND ON_HAND_QTY = 0 AND SUSPENSE_QTY = 0 ))
				);
			
		-- create another location inventory record if
		--   there is none
		--   or there is a non-empty record and there is an inventory status mismatch but we are not on the shipping dock or pre receiving location
		-- or PTS location
		if (@@ROWCOUNT <= 0 
			or ((@dInitAllocQty<>0 or @dInitInTransQty <>0 or  @dInitOnHandQty<>0 or  @dInitSuspQty<>0) 
				and @stInitInvSts<>@stInventorySts 
				and @toLocLocationClass <> N'Shipping Dock'
				and @toLocLocationClass <> N'Receiving Pre-Check In'
				and @toLocLocationClass <> N'Put to Store'))
		begin
			set @dInitAllocQty = 0.0;
			set @dInitInTransQty = 0.0;
			set @dInitOnHandQty = 0.0;
			set @dInitSuspQty = 0.0;

			-- if there is another permanent inventory record for a lot controlled item with a different lot
			-- then when should insert a permanent record
			SELECT @cPermanent = PERMANENT
			  FROM LOCATION_INVENTORY
			 WHERE LOCATION = @stToLoc
			   AND WAREHOUSE = @stToWhs			   
			   AND ITEM = @stItem
			   AND ISNULL(COMPANY,N'!') = ISNULL(@stCompany,N'!')
			   AND PERMANENT = N'Y';
			          
			if ((@stFromInvSts is null OR @stFromInvSts = N'')
              AND (@stInventorySts is null OR @stInventorySts = N''))
            begin
            
           if (@toLocLocationClass <> N'Shipping Dock')  
           --if inventory status is empty then set default status  
           --This condition arises when creating dock work where only "To" location inventory buckets are adjusted without affecting the "From" location  
           -- as a result inventory status is not copied from "From" location  
           -- Work execution will any way over write the value by copying from "From" location  	
              begin  
                    -- Get default inventory status.  
                    SELECT @stInventorySts = SYSTEM_CONFIG_DETAIL.SYSTEM_VALUE  
                    FROM SYSTEM_CONFIG_DETAIL  
                    WHERE SYS_KEY = N'40'  
                    AND RECORD_TYPE = N'Inventory';  
              end;  
            end;

			-- if the inventory attribute ID already exists in any inventory location with a different LP value, 
			-- copy the attribute values to new record and use that ID instead; this is for partial transfers where a new LP id has to be entered
			if (ISNULL(@toLocInvAttributeId, 0) > 0 AND @toLocLocationClass = N'Inventory' AND @stToContId is not null and @cToOnHandEffect = N'+')
			begin 
				select @attrIDCount = COUNT(*) 
				from 
					LOCATION_INVENTORY 
				inner join LOCATION ON 
					LOCATION.LOCATION = LOCATION_INVENTORY.LOCATION 
					AND LOCATION.warehouse = LOCATION_INVENTORY.warehouse 
					AND LOCATION.LOCATION_CLASS = N'Inventory' 
				 where 
					LOCATION_INVENTORY.warehouse = @stToWhs 
					and isnull(LOCATION_INVENTORY.LOC_INV_ATTRIBUTES_ID, 0) = @toLocInvAttributeId 
					and ON_HAND_QTY > 0;
					
				if (@attrIDCount > 0)
				begin
					INSERT INTO LOCATION_INVENTORY_ATTRIBUTES
						(LOC_INV_ATTRIBUTE1, LOC_INV_ATTRIBUTE2, LOC_INV_ATTRIBUTE3, LOC_INV_ATTRIBUTE4, LOC_INV_ATTRIBUTE5, 
						LOC_INV_ATTRIBUTE6, LOC_INV_ATTRIBUTE7, LOC_INV_ATTRIBUTE8, LOC_INV_ATTRIBUTE9, LOC_INV_ATTRIBUTE10, 
						LOC_INV_ATTRIBUTE11, LOC_INV_ATTRIBUTE12, LOC_INV_ATTRIBUTE13, LOC_INV_ATTRIBUTE14, LOC_INV_ATTRIBUTE15, 
						LOC_INV_ATTRIBUTE16, LOC_INV_ATTRIBUTE17, LOC_INV_ATTRIBUTE18, LOC_INV_ATTRIBUTE19, LOC_INV_ATTRIBUTE20, 
						USER_DEF1, USER_DEF2, USER_DEF3, USER_DEF4, USER_DEF5, USER_DEF6, USER_DEF7, USER_DEF8, 
						USER_STAMP, PROCESS_STAMP, DATE_TIME_STAMP, INTERNAL_SHIPPING_CONTAINER_NUM) 
					SELECT 
						LOC_INV_ATTRIBUTE1, LOC_INV_ATTRIBUTE2, LOC_INV_ATTRIBUTE3, LOC_INV_ATTRIBUTE4, LOC_INV_ATTRIBUTE5, 
						LOC_INV_ATTRIBUTE6, LOC_INV_ATTRIBUTE7, LOC_INV_ATTRIBUTE8, LOC_INV_ATTRIBUTE9, LOC_INV_ATTRIBUTE10, 
						LOC_INV_ATTRIBUTE11, LOC_INV_ATTRIBUTE12, LOC_INV_ATTRIBUTE13, LOC_INV_ATTRIBUTE14, LOC_INV_ATTRIBUTE15, 
						LOC_INV_ATTRIBUTE16, LOC_INV_ATTRIBUTE17, LOC_INV_ATTRIBUTE18, LOC_INV_ATTRIBUTE19, LOC_INV_ATTRIBUTE20, 
						USER_DEF1, USER_DEF2, USER_DEF3, USER_DEF4, USER_DEF5, USER_DEF6, USER_DEF7, USER_DEF8, 
						@stUserName, N'INV_PutIntoLocation', GETUTCDATE(), INTERNAL_SHIPPING_CONTAINER_NUM 
					FROM 
						LOCATION_INVENTORY_ATTRIBUTES 
					WHERE 
						OBJECT_ID = @toLocInvAttributeId;
						
					SELECT @toLocInvAttributeId = @@IDENTITY;
					-- reset inv attr id used for history as well
					set @HistToLocInvAttributeId = @toLocInvAttributeId;
				end; -- end inv attr ID exists somewhere else in inventory location
			end; -- end if inv attribute ID exists
			
			-- Avoid setting from expiration date instead of new expiration date during warehouse/inventory transfer
			if (@stTransType = N'360' or @stTransType = N'120')
			begin				
				set @dtFromExpDate = null
			end

			IF EXISTS (SELECT TOP 1 'X' FROM LOCATION_INVENTORY WHERE INTERNAL_LOCATION_INV = @fromIntLocInv) -- JP3 Blake Becker 08/02/2024
			BEGIN
				SET @fromUserdef1 = NULL -- Only populate this if the from location has been deleted
			END
                
			exec @iError = INV_InsertLocationInventory
					@cToAllocEffect, @cToInTransEffect, @cToOnHandEffect, @cToSuspEffect, @dOverrodeVolumePerItem, @dOverrodeWeightPerItem, @dQuantity, @dtExpDate, @dtManDate, @stCompany, @stInventorySts output, @stItem, @stItemDesc, @stLot, @stQuantityUM, @stToLoc, @stToContID, @stParentLogisticsUnit, @stToWhs, @stUserName, 
					@toAgingDate, @dtFromExpDate, @dtFromManDate, @toReceivedDate, @stFromInvSts, @stFromItemColor, @stFromItemDesc, @stFromItemSize, @stFromItemStyle, @cPermanent,
					@stUserDef1, @stUserDef2, @stUserDef3, @stUserDef4, @stUserDef5, @stUserDef6, @dUserDef7, @dUserDef8, @toLocInvAttributeId, @stReferenceType, @fromUserdef1, -- JP3 Blake Becker 08/02/2024
					@iRowCount output, @iIntLocInv output;
			if (@@ERROR <> 0) return -1; else if (@iError <> 0) return @iError;
			set @newLocationInventoryRows = @iRowCount;

			-- if the insert was unsuccessful, some other process modified
			-- the LocationInventory record.  Increment the counter and try 
			-- again.
			if (@iRowCount <= 0)
				set @iNumOfLockFailures = @iNumOfLockFailures + 1;
			else if ((@cToOnHandEffect = N'+' or @cToInTransEffect = N'+')
				       and @internalLocUMs is not null) 
				begin
				IF (NOT EXISTS (SELECT 1 FROM LOCATION_UNIT_OF_MEASURE WHERE 
					LOCATION = @stToLoc			
			AND		WAREHOUSE = @stToWhs
			AND		ITEM = @stItem
			AND		(
					(@stCompany IS NOT NULL AND COMPANY = @STCOMPANY)
					OR (@stCompany IS NULL AND COMPANY IS NULL)
					))
					OR
					(
					@toLocLocationClass =N'Receiving Dock'
			AND
				 EXISTS (SELECT 1 FROM LOCATION_UNIT_OF_MEASURE WHERE   
				 LOCATION = @stToLoc     
			AND  WAREHOUSE = @stToWhs  
			AND  ITEM = @stItem  
			AND  (  
				(@stCompany IS NOT NULL AND COMPANY = @STCOMPANY)  
				OR (@stCompany IS NULL AND COMPANY IS NULL)  
				 )
					)
				 )
					)
				begin
					set @internalLocUMs = replace(@internalLocUMs,N';',N',');
					set @tempToWhs = replace(@stToWhs,N'''',N'''''');	
			
					declare @sql nvarchar(1000);
					if (@toLocLocationClass <> N'Shipping Dock' and @toLocLocationClass <> N'Put to Store'
						and  @shouldCopyLUM =N'Y')
					BEGIN
						set @sql = N'UPDATE LOCATION_UNIT_OF_MEASURE ' +
								N'SET LOCATION ='+ N''''+ @stToLoc + N'''' +
						 		N',WAREHOUSE = '+ N'''' + @tempToWhs + N'''' +
								N',INTERNAL_LOCATION_INV = ' + str(@iIntLocInv) +
								N',PROCESS_STAMP = ''INV_PutintoLocation''' +
									N',USER_STAMP = '+ N'''' + @stUserName + N'''' +
								N',DATE_TIME_STAMP =  GETUTCDATE() '+
					   			N' WHERE INTERNAL_LOC_UM IN ('+ @internalLocUMs +N')';
					
						--Append INTERNAL_CONTAINER_NUM only when @intContNum is not null	
						IF (@intContNum IS NOT NULL AND @toLocLocationClass = N'Receiving Dock')
						BEGIN 
							SET @sql = @sql + N' AND INTERNAL_CONTAINER_NUM = '+ STR(@intContNum);
						END		
					END			
				end				
				else
                 begin
                 set @internalLocUMs = replace(@internalLocUMs,N';',N',')
                  set @sql = N'DELETE FROM LOCATION_UNIT_OF_MEASURE ' +
							N'WHERE INTERNAL_LOC_UM IN ('+ @internalLocUMs + N') ';
                 end
					exec sp_executesql @sql;
									
					if (@@ERROR <> 0) return -1;
									
					set @cAdjustmentCompleted = N'Y';				
				end
			else
				begin
					set @cAdjustmentCompleted = N'Y';
				
				end;
				-- For Full LP Transfer, We have to insert records for remaining internal_location_inv of the destination location
				-- after update has been done by the statement just above it.
				-- so need to check if update has happened correctly or not and will copy the LocationUM of the current LP to all the remaining LPs.				
				if (@toLocLocationClass <> N'Shipping Dock' and @toLocLocationClass <> N'Put to Store'  
					 and  @shouldCopyLUM =N'Y' and @toLocLocationClass <> N'Receiving Dock' )  
				BEGIN	 
					   EXEC INV_CopyLocUmsForDestInventory @stToLoc,@iIntLocInv,@intContNum,@stUserName,N'N',@fromIntLocInv				
				
				END
			
		end -- end if LocationInventory does not exist.
	
		else
		begin			
				
			-- calculate the new quantities.
			set @dNewAllocQty = CASE WHEN @cToAllocEffect = N'+' 
									 THEN @dInitAllocQty + @dQuantity
									 WHEN @cToAllocEffect = N'-' 
									 THEN @dInitAllocQty - @dQuantity
									 ELSE @dInitAllocQty 
									 END;
			set @dNewInTransQty = CASE WHEN @cToInTransEffect = N'+' 
									   THEN @dInitInTransQty + @dQuantity
									   WHEN @cToInTransEffect = N'-' 
									   THEN @dInitInTransQty - @dQuantity
									   ELSE @dInitInTransQty 
									   END;
			set @dNewOnHandQty = CASE WHEN @cToOnHandEffect = N'+' 
									  THEN @dInitOnHandQty + @dQuantity
									  WHEN @cToOnHandEffect = N'-' 
									  THEN CASE WHEN @dInitOnHandQty <= 0 
													 and (@cForceOnHandZero = N'Y' 
													      or @cForceOnHandZero = N'y')
												THEN @dInitOnHandQty
												WHEN @dInitOnHandQty - @dQuantity < 0
													 and (@cForceOnHandZero = N'Y' 
													      or @cForceOnHandZero = N'y')
												THEN 0
												ELSE @dInitOnHandQty - @dQuantity
												END
									  ELSE @dInitOnHandQty 
									  END;
			set @dNewSuspQty = CASE WHEN @cToSuspEffect = N'+' 
									THEN @dInitSuspQty + @dQuantity
									WHEN @cToSuspEffect = N'-' 
									THEN @dInitSuspQty - @dQuantity
									ELSE 	@dInitSuspQty									
									END;

			-- if this location is permanent but there are other permanent locations 
			-- for the same item/company, delete it anyways.
			-- this will handle the case where the item is lot controlled and there 
			-- are multiple permanent locations for different lots
			if (@cPermanent = N'Y' OR @cPermanent = N'y')
			begin
				SELECT INTERNAL_LOCATION_INV
			 	FROM LOCATION_INVENTORY
				WHERE LOCATION = @stToLoc
			 		AND WAREHOUSE = @stToWhs
			 	 	AND ITEM = @stItem
			  	 	AND ISNULL(COMPANY,N'!') = ISNULL(@stCompany,N'!')
			 	  	AND (PERMANENT = N'Y' OR PERMANENT = N'y');
				if (@@ROWCOUNT > 1)
					begin
						set @cPermanent = N'N';
					end;
			end;

			-- if the Location is not permanent and the quantities will be driven
			-- to 0.0, simply delete the record.
			if (@dNewAllocQty = 0.0
				AND @dNewInTransQty = 0.0
				AND @dNewOnHandQty = 0.0
				AND @dNewSuspQty = 0.0
				AND (@cPermanent <> N'Y' AND @cPermanent <> N'y'))
			begin
				exec @iError = INV_ArchiveSerialNumbers @iIntLocInv;

				DECLARE @tableLUOM TABLE (INTERNAL_LOC_UM INT);
				
				INSERT INTO @tableLUOM
				SELECT INTERNAL_LOC_UM
				FROM LOCATION_UNIT_OF_MEASURE
				WHERE INTERNAL_LOCATION_INV = @iIntLocInv;

				UPDATE LOCATION_UNIT_OF_MEASURE
				SET INTERNAL_LOCATION_INV = NULL
					WHERE INTERNAL_LOCATION_INV = @iIntLocInv

				-- make sure initial quantity values match up (optimistic locking).
				DELETE LOCATION_INVENTORY
				 WHERE INTERNAL_LOCATION_INV = @iIntLocInv
				   AND ALLOCATED_QTY = @dInitAllocQty
				   AND IN_TRANSIT_QTY = @dInitInTransQty
				   AND ON_HAND_QTY = @dInitOnHandQty
				   AND SUSPENSE_QTY = @dInitSuspQty;
				SELECT @iError = @@ERROR, @iRowCount = @@ROWCOUNT;
				if (@iError <> 0) return -1;

				-- if the delete was unsuccessful, some other process modified
				-- the LocationInventory record.  Increment the counter and try 
				-- again.
				if (@iRowCount <= 0)
				begin
					set @iNumOfLockFailures = @iNumOfLockFailures + 1;
					
				end; -- end if record modified by another process.
				else
				begin
					set @cAdjustmentCompleted = N'Y';
					
					DELETE FROM LOCATION_UNIT_OF_MEASURE
					WHERE INTERNAL_LOC_UM IN (SELECT INTERNAL_LOC_UM FROM @tableLUOM);
					
					if (@@ERROR <> 0) return -1;
				end; -- end if delete successful.

			end; -- end if deleting LocationInventory
			else
			begin
			if (@dNewAllocQty = 0.0
				AND @dNewInTransQty = 0.0
				AND @dNewOnHandQty = 0.0
				AND @dNewSuspQty = 0.0)
				begin
				  DELETE FROM LOCATION_UNIT_OF_MEASURE
					WHERE INTERNAL_LOCATION_INV =@iIntLocInv;
				
				 -- If the permanent location is emptied, update the location inventory attribute id
				 if((@cPermanent = N'Y' OR @cPermanent = N'y'))
					SET @toLocInvAttributeId = NULL;
				 
				end;

				-- if the inventory attribute ID already exists in any inventory location with a different LP value, 
				-- copy the attribute values to new record and use that ID instead; this is for partial transfers where a new LP id has to be entered
				if (ISNULL(@toLocInvAttributeId, 0) > 0 AND @toLocLocationClass = N'Inventory' AND @stToContId is not null and @dNewOnHandQty > 0)
				begin 
					select @attrIDCount = COUNT(*) 
					from 
						LOCATION_INVENTORY 
					inner join LOCATION ON 
						LOCATION.LOCATION = LOCATION_INVENTORY.LOCATION 
						AND LOCATION.warehouse = LOCATION_INVENTORY.warehouse 
						AND LOCATION.LOCATION_CLASS = N'Inventory' 
					 where 
						LOCATION_INVENTORY.warehouse = @stToWhs 
						and isnull(LOCATION_INVENTORY.LOC_INV_ATTRIBUTES_ID, 0) = @toLocInvAttributeId
						and ON_HAND_QTY > 0 
						and INTERNAL_LOCATION_INV != @iIntLocInv;
						
					if (@attrIDCount > 0)
					begin
						INSERT INTO LOCATION_INVENTORY_ATTRIBUTES
							(LOC_INV_ATTRIBUTE1, LOC_INV_ATTRIBUTE2, LOC_INV_ATTRIBUTE3, LOC_INV_ATTRIBUTE4, LOC_INV_ATTRIBUTE5, 
							LOC_INV_ATTRIBUTE6, LOC_INV_ATTRIBUTE7, LOC_INV_ATTRIBUTE8, LOC_INV_ATTRIBUTE9, LOC_INV_ATTRIBUTE10, 
							LOC_INV_ATTRIBUTE11, LOC_INV_ATTRIBUTE12, LOC_INV_ATTRIBUTE13, LOC_INV_ATTRIBUTE14, LOC_INV_ATTRIBUTE15, 
							LOC_INV_ATTRIBUTE16, LOC_INV_ATTRIBUTE17, LOC_INV_ATTRIBUTE18, LOC_INV_ATTRIBUTE19, LOC_INV_ATTRIBUTE20, 
							USER_DEF1, USER_DEF2, USER_DEF3, USER_DEF4, USER_DEF5, USER_DEF6, USER_DEF7, USER_DEF8, 
							USER_STAMP, PROCESS_STAMP, DATE_TIME_STAMP, INTERNAL_SHIPPING_CONTAINER_NUM) 
						SELECT 
							LOC_INV_ATTRIBUTE1, LOC_INV_ATTRIBUTE2, LOC_INV_ATTRIBUTE3, LOC_INV_ATTRIBUTE4, LOC_INV_ATTRIBUTE5, 
							LOC_INV_ATTRIBUTE6, LOC_INV_ATTRIBUTE7, LOC_INV_ATTRIBUTE8, LOC_INV_ATTRIBUTE9, LOC_INV_ATTRIBUTE10, 
							LOC_INV_ATTRIBUTE11, LOC_INV_ATTRIBUTE12, LOC_INV_ATTRIBUTE13, LOC_INV_ATTRIBUTE14, LOC_INV_ATTRIBUTE15, 
							LOC_INV_ATTRIBUTE16, LOC_INV_ATTRIBUTE17, LOC_INV_ATTRIBUTE18, LOC_INV_ATTRIBUTE19, LOC_INV_ATTRIBUTE20, 
							USER_DEF1, USER_DEF2, USER_DEF3, USER_DEF4, USER_DEF5, USER_DEF6, USER_DEF7, USER_DEF8, 
							@stUserName, N'INV_PutIntoLocation', GETUTCDATE(), INTERNAL_SHIPPING_CONTAINER_NUM 
						FROM 
							LOCATION_INVENTORY_ATTRIBUTES 
						WHERE 
							OBJECT_ID = @toLocInvAttributeId;
							
						SELECT @toLocInvAttributeId = @@IDENTITY;
					end; -- end inv attr ID exists somewhere else in inventory location
				end; -- end if inv attribute ID exists
				
						-- if this allocation result into -ve available qty then do not allow that
						If(@isNegativeAvailableAllowed =N'False' AND @stTransType =N'370')
						begin
							If((@toLocLocationClass = N'Inventory' AND @cToAllocEffect = N'+'  AND (@allocateIntransit =N'Y' OR @allocateIntransit =N'y') AND
							( @dInitOnHandQty + @dInitInTransQty - @dInitSuspQty) < 0) 
							OR
							(@toLocLocationClass =N'Inventory' AND @cToAllocEffect = N'+'AND (@allocateIntransit =N'N' OR @allocateIntransit =N'n') AND 
							( @dInitOnHandQty - @dInitSuspQty) < 0))
							begin
						
								set @stErrorMsg = N'MSG_INVVAL10: ' + dbo.RSCMfn_RtrvMsg(N'MSG_INVVAL10'); 		
								RAISERROR(@stErrorMsg , 18, 1);
								return -1;   
							End
						End;
				exec @iError = INV_UpdateToLocInv
						@iIntLocInv,
						@dInitAllocQty, @dInitInTransQty, @dInitOnHandQty, @dInitSuspQty,
						@dNewAllocQty, @dNewInTransQty, @dNewOnHandQty, @dNewSuspQty, 
						@dOverrodeVolumePerItem, @dOverrodeWeightPerItem, 
						@dtExpDate, @dtManDate, @stCompany, @stInventorySts, @stItem, @stToLoc, @stLot, @stToContId,@stParentLogisticsUnit,@stQuantityUM, @stUserName, @stToWhs,
						@toAgingDate, @dtFromExpDate, @dtFromManDate, @toReceivedDate, @stFromInvSts,
						@stUserDef1,@stUserDef2,@stUserDef3,@stUserDef4,@stUserDef5,@stUserDef6,@dUserDef7,@dUserDef8,@toLocInvAttributeId,@iRowCount output;
				if (@@ERROR <> 0) return -1; else if (@iError <> 0) return @iError;
				
				-- if the update was unsuccessful, some other process modified
				-- the LocationInventory record.  Increment the counter and try 
				-- again.
				if (@iRowCount <= 0)
					begin
						set @iNumOfLockFailures = @iNumOfLockFailures + 1;
					end;
				else
					begin
					
						if(@stInventorySts is null OR @stInventorySts = N'')
						begin
							set @stInventorySts = @stFromInvSts;
						end;

						if ((@cToOnHandEffect = N'+' or @cToInTransEffect = N'+')
				      			 and @internalLocUMs is not null) 
						begin
							set @internalLocUMs = replace(@internalLocUMs,N';',N',');
							set @tempToWhs = replace(@stToWhs,N'''',N'''''');		
									
							--Check whether TO location record exist for the same container numbers
							--If so Delete the FROM location record
							set @sql = N'DELETE FROM LOCATION_UNIT_OF_MEASURE ' +
							N'WHERE INTERNAL_LOC_UM IN ('+ @internalLocUMs + N') '+
							N'AND INTERNAL_CONTAINER_NUM IN ' +
							N'(	SELECT INTERNAL_CONTAINER_NUM '+
								N'FROM LOCATION_UNIT_OF_MEASURE ' +
								N'WHERE INTERNAL_LOCATION_INV = '+ str(@iIntLocInv) + 
								N'  AND	INTERNAL_CONTAINER_NUM IN ' +
								N' ( SELECT INTERNAL_CONTAINER_NUM ' +
									N'FROM LOCATION_UNIT_OF_MEASURE ' +
									N'WHERE INTERNAL_LOC_UM IN ' +
									N'('+ @internalLocUMs +N')' +
								N' )) ';	
							
							exec sp_executesql @sql;
							
							--If TO Location does not contain location UM with same INTERNAL_LOCATION_INV then 
							--update the To Location's UM, else delete the From Location's UM.
							IF (NOT EXISTS (SELECT 1 FROM LOCATION_UNIT_OF_MEASURE WHERE 
							INTERNAL_LOCATION_INV = @iIntLocInv))
							BEGIN
								IF (@toLocLocationClass <> N'Shipping Dock' and @toLocLocationClass <> N'Put to Store' 
										and  @shouldCopyLUM =N'Y')
								BEGIN
									set @sql = N'UPDATE LOCATION_UNIT_OF_MEASURE ' +
										N'SET LOCATION ='+ N''''+ @stToLoc + N'''' +
						 				N',WAREHOUSE = '+ N'''' + @tempToWhs + N'''' +
										N',INTERNAL_LOCATION_INV = ' + str(@iIntLocInv) +
										N',PROCESS_STAMP = ''INV_PutintoLocation''' +
						       				 N',USER_STAMP = '+ N'''' + @stUserName + N'''' +
										N',DATE_TIME_STAMP =  GETUTCDATE() '+
					   					N' WHERE INTERNAL_LOC_UM IN ('+ @internalLocUMs +N')';
								
									exec sp_executesql @sql;
									IF( @toLocLocationClass   <> N'Receiving Dock')
									BEGIN									
									EXEC INV_CopyLocUmsForDestInventory @stToLoc,@iIntLocInv,@intContNum,@stUserName,N'N',@fromIntLocInv		
									END
								END;
								ELSE IF (@toLocLocationClass = N'Shipping Dock' or @toLocLocationClass = N'Put to Store')
								BEGIN
									set @sql = N'SELECT @fromLoc = LOCATION FROM  LOCATION_UNIT_OF_MEASURE ' +									
												N' WHERE INTERNAL_LOC_UM IN ('+ @internalLocUMs +N')';
											
									EXEC sp_executesql 
										@query = @sql, 
										@params = N'@fromLoc nvarchar(25) OUTPUT', 
										@fromLoc = @fromLoc OUTPUT;
									
									SELECT @fromLocLocationClass = LOCATION_CLASS
		  								FROM LOCATION
		 								WHERE LOCATION = @fromLoc

									if (@fromLocLocationClass = N'Equipment')
									BEGIN
										set @sql = N'DELETE FROM LOCATION_UNIT_OF_MEASURE 
										WHERE LOCATION = @fromLoc
										AND INTERNAL_LOC_UM IN ('+ @internalLocUMs +N')';
										
										EXEC sp_executesql 
										@query = @sql, 
										@params = N'@fromLoc nvarchar(25) ', 
										@fromLoc = @fromLoc ;
									END;

									-- if automatic putaway
									if ((@toLocLocationClass = N'Shipping Dock' OR @toLocLocationClass = N'Put to Store')
									 AND @fromLocLocationClass=N'Inventory')
									BEGIN
										set @sql = N'DELETE FROM LOCATION_UNIT_OF_MEASURE WHERE LOCATION = @fromLoc
										AND NOT EXISTS (SELECT 1 FROM LOCATION_INVENTORY where LOCATION = @fromLoc 
										AND ITEM = @stItem AND (COMPANY=@stCompany OR (@stCompany is null and COMPANY is null))			
										AND (LOT=@stLot OR (@stLot is null and LOT is null))
										AND (ON_HAND_QTY <> 0 OR SUSPENSE_QTY <> 0 OR ALLOCATED_QTY <> 0))
										AND INTERNAL_LOC_UM IN ('+ @internalLocUMs +N')';
										
										EXEC sp_executesql 
										@query = @sql, 
										@params = N'@fromLoc nvarchar(25),@stItem nvarchar(50),@stCompany nvarchar(50),@stLot nvarchar(25)', 
										@fromLoc = @fromLoc,
										@stCompany =@stCompany,
										@stLot = @stLot,
										@stItem =@stItem;
									END;

								END;
							END;
							ELSE
							BEGIN
																											 
								set @sql = N'SELECT @fromLoc = LOCATION FROM  LOCATION_UNIT_OF_MEASURE ' +									
											N' WHERE INTERNAL_LOC_UM IN ('+ @internalLocUMs +N')';
																					
								EXEC sp_executesql 
									@query = @sql, 
									@params = N'@fromLoc nvarchar(25) OUTPUT', 
									@fromLoc = @fromLoc OUTPUT;
							   
							   set @sql = N'DELETE FROM LOCATION_UNIT_OF_MEASURE WHERE LOCATION = @fromLoc
										AND NOT EXISTS (SELECT 1 FROM LOCATION_INVENTORY where LOCATION = @fromLoc 
										AND ITEM = @stItem AND (COMPANY=@stCompany OR (@stCompany is null and COMPANY is null))			
										AND (LOT=@stLot OR (@stLot is null and LOT is null))
										AND (ON_HAND_QTY <> 0 OR SUSPENSE_QTY <> 0 OR ALLOCATED_QTY <> 0))
										AND INTERNAL_LOC_UM IN ('+ @internalLocUMs +N')';
										
										EXEC sp_executesql 
										@query = @sql, 
										@params = N'@fromLoc nvarchar(25),@stItem nvarchar(50),@stCompany nvarchar(50),@stLot nvarchar(25)', 
										@fromLoc = @fromLoc,
										@stCompany =@stCompany,
										@stLot = @stLot,
										@stItem =@stItem;	
								
							
							END;
									
							if (@@ERROR <> 0) return -1;
						end;
						set @cAdjustmentCompleted = N'Y';
					end;
			end; -- end if updating LocationInventory.
		end; -- end if LocationInventory exists.
	end; -- end optimistic lock.
	
	--This is to add TO location record to LOCATION_UNIT_OF_MEASURE when its intransit effect with work
	-- or onhand effect without work. Also when its @internalLocUMs is null	
	IF ((@cToOnHandEffect = N'+' OR @cToInTransEffect = N'+'))
	BEGIN

		IF (NOT EXISTS (SELECT 1 FROM LOCATION_UNIT_OF_MEASURE WHERE 
					INTERNAL_LOCATION_INV = @IIntLocInv AND WAREHOUSE = @stToWhs
					AND (((@intContNum IS NOT NULL AND INTERNAL_CONTAINER_NUM = @intContNum)
						OR (@intContNum IS NULL AND INTERNAL_CONTAINER_NUM IS NULL))
						OR (@toLocLocationClass   <> N'Receiving Dock'))
					AND (@stTransType <> N'90')))
					
		BEGIN	
		
		 IF (EXISTS 
			(SELECT 1 FROM LOCATION_UNIT_OF_MEASURE  
			WHERE	
				LOCATION = @stToLoc 			
				AND		WAREHOUSE = @stToWhs
				AND		ITEM = @stItem
				AND		
				(
					(@stCompany IS NOT NULL AND COMPANY = @STCOMPANY)
					OR (@stCompany IS NULL AND COMPANY IS NULL)
				)
				AND (INTERNAL_CONTAINER_NUM IS NULL OR @toLocLocationClass   <> N'Receiving Dock')	--In case of check-in while Receiving, made sure duplicate records are not created
			))	
					
			BEGIN
           INSERT INTO LOCATION_UNIT_OF_MEASURE 
					(ITEM, COMPANY, INTERNAL_CONTAINER_NUM, SEQUENCE, QUANTITY_UM, CONVERSION_QTY, LENGTH, WIDTH,
					HEIGHT, DIMENSION_UM, WEIGHT, WEIGHT_UM, USER_DEF1, USER_DEF2, USER_DEF3, USER_DEF4, 
					USER_DEF5, USER_DEF6,USER_DEF7, USER_DEF8, USER_STAMP, PROCESS_STAMP, DATE_TIME_STAMP,
					TREAT_FULL_PCT,	WAREHOUSE, LOCATION, MOVEMENT_CLS, TREAT_AS_LOOSE, EPC_PACKAGE_ID,
					INTERNAL_LOCATION_INV)
			SELECT DISTINCT
					ITEM, COMPANY, 
					CASE WHEN  @toLocLocationClass  = N'Receiving Dock'
						THEN INTERNAL_CONTAINER_NUM 
						ELSE NULL END, SEQUENCE, QUANTITY_UM, CONVERSION_QTY, LENGTH, WIDTH,
					HEIGHT, DIMENSION_UM, WEIGHT, WEIGHT_UM, USER_DEF1, USER_DEF2, USER_DEF3, USER_DEF4, 
					USER_DEF5, USER_DEF6, USER_DEF7, USER_DEF8, USER_STAMP, N'INV_PutintoLocation', 
					GETUTCDATE(), TREAT_FULL_PCT, WAREHOUSE, @stToLoc, MOVEMENT_CLS, TREAT_AS_LOOSE,								EPC_PACKAGE_ID,	@iIntLocInv
					FROM	LOCATION_UNIT_OF_MEASURE 
			WHERE	LOCATION = @stToLoc 			
			AND		WAREHOUSE = @stToWhs
			AND		ITEM = @stItem
			AND		(
					(@stCompany IS NOT NULL AND COMPANY = @STCOMPANY)
					OR (@stCompany IS NULL AND COMPANY IS NULL)
					)
			AND @toLocLocationClass <> N'Shipping Dock'
			and @toLocLocationClass <> N'Put to Store'
			and Not Exists (select 1 from LOCATION_UNIT_OF_MEASURE where INTERNAL_LOCATION_INV =@iIntLocInv)
           END
           ELSE
           BEGIN		
					-- For transfer of partial quantity of a LP, we need to insert LocationUm for all LPs of the destination location.
					-- Hence need to copy the LocationUM of source location .
					if (@toLocLocationClass <> N'Shipping Dock' and @toLocLocationClass <> N'Put to Store'
						and  @shouldCopyLUM =N'Y' and @toLocLocationClass   <> N'Receiving Dock')
					BEGIN						
						EXEC INV_CopyLocUmsForDestInventory @stToLoc,@iIntLocInv,@intContNum,@stUserName,N'Y',@fromIntLocInv				
					END
           END	
			
		END
							
	END
	
	-- if the inventory was initially empty, process accordingly.
		if (@dInitAllocQty = 0.0
		   and @dInitInTransQty = 0.0
			and @dInitOnHandQty = 0.0
			and @dInitSuspQty = 0.0)
		begin
			-- if we are dealing with a lot, insert the new record.
			if (@stLot is not null)
			begin
				
				exec @iError = INV_ProcessLotInNewInventory @stToLoc,@stLot, @stItem, @stCompany, 
							@stToWhs, @dtExpDate, @stInventorySts,@argumentGroupId;
				if (@@ERROR <> 0) return -1; else if (@iError <> 0) return @iError;
				
			end; -- end if lot specified.
		end; -- end if location was empty.

	-- if the inventory was emptied, execute additional logic.
		if (@dNewAllocQty = 0.0
		   AND @dNewInTransQty = 0.0
		   AND @dNewOnHandQty = 0.0
		   AND @dNewSuspQty = 0.0)
			begin
				if (@stLot is not null)
					begin
						exec @iError = INV_ProcessLotWhenEmptyingInv @stToLoc, @stLot, @stItem, @stCompany, @stToWhs;
						if (@@ERROR <> 0) return -1; else if (@iError <> 0) return @iError;
					end;
			end;

	-- if the adjustment was not completed, raise an error and return.
	if (@cAdjustmentCompleted is null)
	begin
		set @stErrorMsg = 
			N'MSG_INVENTORY05: ' + dbo.RSCMfn_RtrvMsg(N'MSG_INVENTORY05'); 				
		RAISERROR(@stErrorMsg , 18, 1);
		return -1;
	end; -- end if could not modify inventory.

	if(@internalLocUMs is not null) 
	begin
	set @sql = N'DELETE FROM LOCATION_UNIT_OF_MEASURE 
										WHERE INTERNAL_LOCATION_INV is null
										AND INTERNAL_LOC_UM IN ('+ @internalLocUMs +N')';
																				
	EXEC sp_executesql 
		@query = @sql;
	End

	-- update the Location status.
	exec @iError = INV_UpdateLocation 
			1,
			@stToLoc, @stToWhs, @stUserName,
			@dNewAllocQty, @dNewInTransQty, @dNewOnHandQty, @dNewSuspQty,
			@cToOnHandEffect, @stCompany, @stItem, @stQuantityUM, @stLot,
			@stToContId;
	if (@@ERROR <> 0) return -1; else if (@iError <> 0) return @iError;
	
	if (@dNewInTransQty is null
		AND @cToInTransEffect=N'-'
		AND @dInitInTransQty=0.0
		AND @newLocationInventoryRows=1) 
		begin
			set   @dInitInTransQty=@dQuantity;
		end

   if(@afterExpDateTime is null and(@stTransType = N'360' or @stTransType = N'120'))
   begin
	   set @afterExpDateTime = CASE -- if not lot controlled, use the max time.
					 WHEN @stLot is null
					 THEN null
					 -- if lot controlled and from value exists, use it.
					 WHEN @dtFromExpDate is not null
					 THEN @dtFromExpDate
					 -- otherwise, use the specified value.
					 ELSE @dtExpDate 
					 END
	end
	else
	begin
		set @afterExpDateTime =@dtFromExpDate
	end
	-- write TransactionHistory.
	exec @iError = INV_SaveHistInvChg
			1,
			@cForceOnHandZero, @cToAllocEffect, @cToInTransEffect, @cToOnHandEffect, @cReversal, 
			@cToSuspEffect, @dQuantity, @dReferenceLine, @iInternalNum, @stCompany, @stToContId,
			@stEquipmentType, @stInventorySts, @stItem, @stToLoc, @stLot, @stQuantityUM, @stRecContID,
			@stReferenceID, @stReferenceType, @stTeam, @stTransType, @stUserDef1, @stUserDef2, 
			@stUserDef3, @stUserDef4, @stUserDef5, @stUserDef6, @dUserDef7, @dUserDef8, @stUserName, 
			@stToWhs, @stWorkGroup, @stWorkType, @stWorkUnit,
			@stCompany, @stToWhs, @dInitAllocQty, @dInitInTransQty, @dInitOnHandQty, @dInitSuspQty, @stInitInvSts,
			@argumentGroupId,@afterExpDateTime,@initExpDate,@HistToLocInvAttributeId,
			@cTransHistActive;
	if (@@ERROR <> 0) return -1; else if (@iError <> 0) return @iError;
-- end INV_PutIntoLocation


GO
