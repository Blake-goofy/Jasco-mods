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
	10790		| RAB			| 03/20/03	| Add forceOnHandToZero.
	10753		| RAB			| 03/24/03	| Added key to returned error.
	11191		| RAB			| 04/29/03	| Pass forceOnHandZero to INV_SaveHistInvChg.
	9493		| PK			| 04/23/03	| Fix the ILC UM conversion during INV Adjust
	11247		| RLE			| 05/12/03	| throw exception if container tracked and user did not specify container.
	11870       | TBS			| 09/16/03  | Added Multi-Byte support.
	11922		| ANB			| 11/03/03	| If container tracked, only delete location UMs for specified container
	10684		| LJM			| 11/04/03	| Support lot-controlled permanent locations
	12169		| RAB			| 01/13/04	| Delete overrides when emptying a permanent loc.
	13837		| LJM			| 02/12/04	| fixed too many rows returned error
	14145		| RRD			| 03/09/04	| Create location inv record if it does not exist.
	14473		| TDA			| 04/13/04	| Fixed Apostrophes
	14842		| RAB			| 09/09/04	| Added argumentGroupId.
	14972		| LJM			| 09/20/04	| delete serial numbers when location inventory deleted
	15113		| KMD			| 09/23/04	| Allow omission of container ID when short picking from Container Tracked location
	15433		| LJM			| 10/13/04	| do not log negative inventory audit
	16686		| SMF			| 05/26/05	| override default status when inserting a new record
	16413           	| KSP                   	| 04/19/05      	| Expanded Lot Control
	16820           	| RR	                   	| 07/28/05      	| Passed toCompany & toWhs to INV_SaveHistInvChg

	12985		| VK			| 09/24/05	| Modified to remove overrides for container tracked locs
	18778		| SAT			| 03/15/05	| Condition changed for Permanent Location
	19167		| SAT			| 05/05/06	| License Plate change
	19166		| KSP			| 05/23/06	| License Plate Tracking
	19165		| VK			| 08/21/06	| License Plate Tracking
	18778		| VK			| 12/01/06	| Fixed to update lot on permanent lot location
	20413		| AK			| 12/04/06	| Store the status befor deleting the values in Location_Inventory
	Picks from a Location.
	776			| SPS			| 03/21/07	| Change the logic for Oracle to not to exit the loop if no Loc UM 
												record is found.
	7392		| JAG			| 07/30/07	| Modified to try deleting the lot when doing warehouse transfers 
											| and the location will be empty
	18287		| BB			| 02/25/08	| Changes made to handle null value.
	22534		| SMS			| 03/28/08	| Added @fromIntLocInv parameter for consolidation during locate
											  when Item UM override is done
	24198		| KRG			| 04/15/08	| Passed From ContainerID to INV_ProcessLotWhenEmptyingInv
	27133		| BB			| 05/23/08	| Passed FromContId to INV_InsertLocationInventory in place of RecContID
	Parameters
		Adjustment information.
	27592		| AG			| 05/28/08	| Removed the check for LOT on determining cycle count eligibility.
	33159       | AK            | 08/28/08  | Modified to move the location Ums to the to location if the from location is a permanent location
	51901		| SVS			| 05/19/09  | Added logic to set the Exp dates correctly.
	52334		| SVS			| 05/22/09  | Pass  correct exp date to the transaction history.
	66433		| SSH			| 07/03/10	| Added parameter @fromLocInvAttributeId.	
	66621		| NB			| 03/24/10	| Modified to adjust the suspense qty 
    70073		| SSH			| 05/26/10	| Passed parameter @fromLocInvAttributeId to INV_SaveHistInvChg.
	70383		| NB			| 06/02/10	| Reverted back the change done for 66621
	70744		| DSK			| 06/08/10	| Removed the check for LP along with location inventory attributes
	69969		| DRK			| 07/09/10	| Fixed the check for lot items
	76933		| SSC			| 11/16/10	| Fixed issue with transaction history logging with attributes incase location is empty
	77170		| RJR			| 11/15/10	| Passed inventory attributes Id to INV_CheckLocThreshold.
	78968		| RJR			| 02/10/11	| Fixed duplicate inventory attribute ID when partial picking to LP tracked location. 
	78968		| DN			| 02/18/11	| Modified fix for 78968 to check for from inventory attribute to take care for multiple LPs with same attribute id.
	82420		| RJR			| 03/22/11	| Fixed bug where inventory attributes do not get logged in override location history for permanent locations. 
	82175		| DRK			| 04/13/2011| Fixed Inv Status in Xn History for Inv Mgmt
	84202		| DRK			| 05/14/2011| Fixed Inv Adjustment when adding items to Empty Permanent Locations
	85301		| DRK			| 05/23/2011| Fixed Expiration Date for newly added LP
	86637       | MDL			| 07/19/11  | Return error message if allocation result into -ve available for only inventory location class.
	94517		| MMM			| 02/14/12	| Implemented Mutex lock(sp_getapplock) to avoid duplicate inventory record insertion	
	86845       | NRJ			| 04/06/12  | Negative inventory is being created at the location inventory record without attributes on performing negative adjustment of inventory with attributes is fixed.
	98464		| TDA			| 04/25/12	| Update Logistics Unit for Cycle Count to Empty Location
	98485		| TDA			| 05/02/12	| Handle Inventory Attributes for a permanent empty location correctly
	132035		| SAM			| 11/08/13	| Passed @stReferenceType to INV_InsertLocationInventory
	144069      | MDL	        | 04/14/15  | Modify to remove ship container number form AR table in case of short putaway.
	168986      | MDL           | 11/02/15  | Removed release of app lock ( It will be release when transcation is completed) as it was resulting into deadlock when running series of adjust in one transcation.
	171258		| MHM			| 01/10/16	| Passed @stInventorySts to INV_UpdateFromLocInv
	212950		| NRJ			| 09/15/16	| Modified such that -ve inventory wont be created during invTransfer.
	228202		| MHM			| 10/04/18  | System should have assigned the inventory status that is defined in the Inventory Control Values Default inventory status for adjustments When the transfer action emptied out the permanent location.
	235836		| NRJ			| 09/20/19	| Modified to allow having negetive on hand quantity(this can happen if allowPickIntransit is turned on from RF).
	JP3			| Blake Becker	| 08/02/2024| Collecting USER_DEF1 from the inventory we delete.
*/

-- #DEFINE WMW.JSharp.General com.pronto.general.Constants Constants;


CREATE OR ALTER   PROCEDURE [dbo].[INV_PickFromLocation](
	@cForceOnHandZero nchar(1), -- SYSTEM_CREATED used to set char type
	@cFromAllocEffect nchar(1), -- SYSTEM_CREATED used to set char type
	@cFromInTransEffect nchar(1), -- SYSTEM_CREATED used to set char type
	@cFromOnHandEffect nchar(1), -- SYSTEM_CREATED used to set char type
	@cFromSuspEffect nchar(1), -- SYSTEM_CREATED used to set char type
	@cToInTransitEffect nchar(1),
	@cToOnHandEffect nchar(1),
	@cReversal nchar(1), -- SYSTEM_CREATED used to set char type
	@dOverrodeVolumePerItem numeric(28,5),
	@dOverrodeWeightPerItem numeric(28,5),
	@dQuantity numeric(19,5),
	@dReferenceLine numeric(19,5),
	@dtExpDate datetime,
	@dtManDate datetime,
	@iInternalNum numeric(9),
	@stCompany nvarchar(25),
	@stEquipmentType nvarchar(25),
	@stFromContId nvarchar(50),
	@stFromLoc nvarchar(25),	
	@stFromWhs nvarchar(25),
	@stInventorySts nvarchar(50),
	@stItem nvarchar(50),
	@stItemDesc nvarchar(100),
	@stLot nvarchar(25),
	@stQuantityUM nvarchar(25),
	@stRecContID nvarchar(25),
	@parentLogisticsUnit nvarchar(50),
	@stReferenceID nvarchar(25),
	@stReferenceType nvarchar(50),
	@stTeam nvarchar(50),
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
	@stToWhs nvarchar(25),
    @fromLocInvAttributeId numeric(9),
	@isNegativeAvailableAllowed bit = false,
	@dtFromAgingDate datetime output,
	@dtFromExpDate datetime output,
	@dtFromManDate datetime output,
	@dtFromRecDate datetime output,
	@stFromInvSts nvarchar(50) output,
	@stFromItemColor nvarchar(25) output,
	@stFromItemDesc nvarchar(100) output,
	@stFromItemSize nvarchar(25) output,
	@stFromItemStyle nvarchar(25) output,
	@cTransHistActive nvarchar(250) output,
	@internalLocUMs nvarchar(100) output,
	@fromIntLocInv numeric(9) output, --Needed for location consolidation
	@fromUserdef1 nvarchar(25) output -- Needed for Decant UD1. JP3 Blake Becker 08/02/2024
	)
AS
	SET NOCOUNT ON;

	-- constant that determines how many times the
	-- optimistic lock will be attepted before an error is thrown.
	declare @iOPTIMISTICLOCKFAILUREMAX int;
	set @iOPTIMISTICLOCKFAILUREMAX = 3;

	-- local variables
	declare @dtAfterExpDate datetime;
	declare @cAdjustmentCompleted nchar(1);
	declare @cPermanent nchar(1);
	declare @cOriginalPermanent nchar(1);
	declare @dInitAllocQty numeric(19,5);
	declare @dInitInTransQty numeric(19,5);
	declare @dInitOnHandQty numeric(19,5);
	declare @dInitSuspQty numeric(19,5);
	declare @dNewAllocQty numeric(19,5);
	declare @dNewInTransQty numeric(19,5);
	declare @dNewOnHandQty numeric(19,5);
	declare @dNewSuspQty numeric(19,5);
	declare @dTotalOnHandQty numeric(19,5);
	declare @iError int;
	declare @iIntLocInv numeric(9);
    declare @initExpDate datetime;
	declare @iNumOfLockFailures int;
	declare @iRowCount int;
	declare @stCntTrack nchar(1);
	declare @stErrorMsg nvarchar(2000);
	declare @stInitInvSts nvarchar(50);
	declare @stDefaultInvSts nvarchar(200);
    declare @totalLotQty int;
    declare @internallocUM int;
    declare @histFromLocInvAttributeId numeric(9);
	declare @originalFromInvAttrId numeric(9);
	declare @allocateIntransit nchar(1)
	declare @fromLocationClass nvarchar(25)
	declare @lockResource nvarchar(255);
	declare @lockResult int;
	declare @iUserdef1 nvarchar(25); -- JP3 Blake Becker 08/02/2024
	
	set @lockResult = -1;
	
	-- there are some instances where the from inventory attributes id are changed within this stored proc, so capture them up front for history purposes
	set @originalFromInvAttrId = @fromLocInvAttributeId;

	-- perform the update in an optimistic lock so that two 
	-- processes do not update the same inventory at exactly the
	-- same time and corrupt inventory.
	set @iNumOfLockFailures = 0;
	WHILE (@cAdjustmentCompleted is null
		   AND @iNumOfLockFailures < @iOPTIMISTICLOCKFAILUREMAX)
	begin
		set @iRowCount = 0;
		WHILE @iRowCount <= 0
		begin
			-- if to location is LP tracked and partial picks were done so that work instructions were split, it is possible that the 
			-- inv attr passed does not even exist for the LP anymore as a new one may have been created; check this and if it does not 
			-- exist, get the new inv att ID for the LP at the location 
			if (ISNULL(@fromLocInvAttributeId, 0) > 0 AND @stFromContId is not null AND NOT EXISTS (SELECT TOP 1 1 FROM LOCATION_INVENTORY WHERE LOC_INV_ATTRIBUTES_ID = @fromLocInvAttributeId and LOGISTICS_UNIT = @stFromContId))
			begin 
				declare @existingInvAttrId numeric(9);
				declare @lpSeparator nvarchar(1);
				declare @recContLikeId nvarchar(50);
				declare @fromContLikeId nvarchar(50);
				select @lpSeparator = SYSTEM_VALUE from SYSTEM_CONFIG_DETAIL where RECORD_TYPE = N'Inventory' and SYS_KEY = N'200';

				-- the LP could have a suffix so we need to check for that; we know @stFromContId will not be null because we checked for it above, 
				-- but we do need to check for @stRecContID
				if (@stRecContID is null)
					set @recContLikeId = @stRecContID;
				else
					set @recContLikeId = @stRecContID + @lpSeparator + N'%';
				set @fromContLikeId = @stFromContId + @lpSeparator + N'%';

				SELECT @existingInvAttrId = LOC_INV_ATTRIBUTES_ID
				FROM LOCATION_INVENTORY
				WHERE LOCATION = @stFromLoc
				   AND WAREHOUSE = @stFromWhs
				   AND ITEM = @stItem
				   AND ISNULL(COMPANY,N'!') = ISNULL(@stCompany,N'!')
				   AND (
		   				ISNULL(LOT,N'!') = ISNULL(@stLot,N'!')
		   				OR (LOT IS NULL AND PERMANENT = N'Y')
						)
		  
					AND (
		   				 LOGISTICS_UNIT LIKE @recContLikeId OR LOGISTICS_UNIT = @stRecContID
		   		    			OR
		   				 (LOGISTICS_UNIT LIKE @fromContLikeId OR LOGISTICS_UNIT = @stFromContId 
								 OR (LOGISTICS_UNIT IS NULL AND PERMANENT = N'Y'))
					     )
					AND (  
						 ISNULL(LOC_INV_ATTRIBUTES_ID,0) = ISNULL(@fromLocInvAttributeId,0)         
					     ); 	

				if (@existingInvAttrId is not null and @fromLocInvAttributeId != @existingInvAttrId)
				begin
					SET @fromLocInvAttributeId = @existingInvAttrId;
				end;
			end;

			SET @lockResource = ISNULL(@stFromLoc, N'') + ISNULL(@stFromWhs, N'') + ISNULL(@stItem, N'') + ISNULL(@stCompany, N'') + ISNULL(@stLot, N'') + ISNULL(@stFromContId, N'') + CONVERT(nvarchar, ISNULL(@fromLocInvAttributeId, 0)); 
			exec @lockResult = sp_getapplock @Resource=@lockResource, @LockMode = N'Exclusive', @LockTimeout=-1
			
			-- before we update the LocationInventory record, grab
			-- some initial values for history.
			SELECT @iIntLocInv = LI.INTERNAL_LOCATION_INV,
				   @cPermanent = LI.PERMANENT,
				   @cOriginalPermanent = LI.PERMANENT,
				   @dInitAllocQty = LI.ALLOCATED_QTY,
				   @dInitInTransQty = LI.IN_TRANSIT_QTY,
				   @dInitOnHandQty = LI.ON_HAND_QTY,
				   @dInitSuspQty = LI.SUSPENSE_QTY,
				   @stInitInvSts = LI.INVENTORY_STS,
				   @stCntTrack = LOC.TRACK_CONTAINERS,
                   @initExpDate = LI.EXPIRATION_DATE,
				   @allocateIntransit = LOC.ALLOCATE_IN_TRANSIT,
				   @fromLocationClass = LOC.LOCATION_CLASS,
				   @iUserdef1 = LI.USER_DEF1 -- JP3 Blake Becker 08/02/2024
			  FROM LOCATION_INVENTORY LI WITH (updlock),
	  			LOCATION LOC
			 WHERE LOC.LOCATION = LI.LOCATION
			   AND LOC.WAREHOUSE = LI.WAREHOUSE	
			   AND LI.LOCATION = @stFromLoc
			   AND LI.WAREHOUSE = @stFromWhs
			   AND LI.ITEM = @stItem
			   AND (LI.COMPANY IS NULL OR (ISNULL(LI.COMPANY,N'!') = ISNULL(@stCompany,N'!')))
               AND (
				ISNULL(LI.LOC_INV_ATTRIBUTES_ID,0) = ISNULL(@fromLocInvAttributeId,0)	
				OR (LI.LOC_INV_ATTRIBUTES_ID IS NULL AND PERMANENT = N'Y')			
					)
			   AND (
			   	ISNULL(LOT,N'!') = ISNULL(@stLot,N'!')
			   	OR (LOT IS NULL AND PERMANENT = N'Y')
			       )
			   
			   AND (
			   	  LOGISTICS_UNIT = @stRecContID
			   		OR
			   	(ISNULL(LOGISTICS_UNIT,N'!')  = ISNULL(@stFromContId,N'!')
			         OR (LOGISTICS_UNIT IS NULL AND PERMANENT = N'Y'))
			);

	
			SELECT @iRowCount = @@ROWCOUNT;

			-- if the LocationInventory does not exist, create it
			if (@iRowCount <= 0)
			begin
				if (@stInventorySts is null
				    OR @stInventorySts = N'')
				begin
					-- Get default inventory status.
					SELECT @stDefaultInvSts = SYSTEM_CONFIG_DETAIL.SYSTEM_VALUE
					FROM SYSTEM_CONFIG_DETAIL
					WHERE SYS_KEY = N'40'
					AND RECORD_TYPE = N'Inventory';
				end;
				else SELECT @stDefaultInvSts = @stInventorySts;
				
				--Pass this variable in save history
				set @dtAfterExpDate = @dtFromExpDate;

				-- Insert location inventory record.
				exec @iError = INV_InsertLocationInventory
					N'', N'', N'', N'', @dOverrodeVolumePerItem, @dOverrodeWeightPerItem, 
					0, @dtExpDate, @dtManDate, @stCompany, @stDefaultInvSts output, @stItem, @stItemDesc, @stLot, @stQuantityUM, 
					@stFromLoc, @stFromContId, @parentLogisticsUnit, @stFromWhs, @stUserName, @dtFromAgingDate, @dtFromExpDate, @dtFromManDate, @dtFromRecDate, @stFromInvSts, 
					@stFromItemColor, @stFromItemDesc, @stFromItemSize, @stFromItemStyle, @cPermanent, 
					@stUserDef1, @stUserDef2, @stUserDef3, @stUserDef4, @stUserDef5, @stUserDef6, @dUserDef7, @dUserDef8, @fromLocInvAttributeId, @stReferenceType,
					@iRowCount output, @iIntLocInv output;
				if (@@ERROR <> 0) return -1; else if (@iError <> 0) return @iError;
				
				-- Update location status back to Picking.
				UPDATE LOCATION SET LOCATION_STS = N'Picking'
				WHERE LOCATION = @stFromLoc AND WAREHOUSE = @stFromWhs AND LOCATION_STS <> N'Picking';
			end; -- end if LocationInventory does not exist.   
		end;
		
		-- if container tracked and user did not specify container 
		if ((@cFromOnHandEffect = N'+'
			AND @stCntTrack = N'Y' 
			AND @stFromContId is null)
		    OR (@cFromOnHandEffect = N'-'
			AND @stCntTrack = N'Y' 
			AND @dInitOnHandQty > 0
			AND @stFromContId is null))
		begin
			set @stErrorMsg = N'MSG_INVENTORY09: ' + dbo.RSCMfn_RtrvMsg(N'MSG_INVENTORY09');
			RAISERROR(@stErrorMsg, 18, 1);
			return -1;
		end; -- end if user did not specify a container.

		-- calculate the new quantities.
		set @dNewAllocQty = CASE WHEN @cFromAllocEffect = N'+' 
								 THEN @dInitAllocQty + @dQuantity
								 WHEN @cFromAllocEffect = N'-' 
								 THEN @dInitAllocQty - @dQuantity
								 ELSE @dInitAllocQty 
								 END;
		set @dNewInTransQty = CASE WHEN @cFromInTransEffect = N'+' 
								   THEN @dInitInTransQty + @dQuantity
								   WHEN @cFromInTransEffect = N'-' 
								   THEN @dInitInTransQty - @dQuantity
								   ELSE @dInitInTransQty 
								   END;
		set @dNewOnHandQty = CASE WHEN @cFromOnHandEffect = N'+' 
								  THEN @dInitOnHandQty + @dQuantity
								  WHEN @cFromOnHandEffect = N'-' 
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
		set @dNewSuspQty = CASE WHEN @cFromSuspEffect = N'+' 
								THEN @dInitSuspQty + @dQuantity
								WHEN @cFromSuspEffect = N'-' 
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
			 WHERE LOCATION = @stFromLoc
			   AND WAREHOUSE = @stFromWhs
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
			AND @dNewSuspQty = 0.0)
		begin
			if(@cPermanent <> N'Y' AND @cPermanent <> N'y')
			begin				
			-- select the output parameters before deleting.
			SELECT @dtFromAgingDate = AGING_DATE,
			   @dtFromExpDate = EXPIRATION_DATE,
			   @dtFromManDate = MANUFACTURED_DATE,
			   @dtFromRecDate = RECEIVED_DATE,
			   @stFromInvSts = INVENTORY_STS,
			   @stFromItemColor = ITEM_COLOR,
			   @stFromItemDesc = ITEM_DESC,
			   @stFromItemSize = ITEM_SIZE,
			   @stFromItemStyle = ITEM_STYLE 
			FROM LOCATION_INVENTORY
			WHERE INTERNAL_LOCATION_INV = @iIntLocInv;
			
		
			exec @iError = INV_ArchiveSerialNumbers @iIntLocInv , @stTransType;
			end;
			
			if(@cPermanent = N'Y' OR @cPermanent = N'y')
			begin
				SET @fromLocInvAttributeId = NULL;	
			end
			
			if (@cToOnHandEffect <> N'+' AND @cToInTransitEffect <> N'+')
			begin
				DELETE FROM LOCATION_UNIT_OF_MEASURE
				WHERE
					INTERNAL_LOCATION_INV = @iIntLocInv;

				if (@@ERROR <> 0) return -1;
			end
			else if exists(select internal_loc_um from location_unit_of_measure
					  where internal_location_inv = @iIntLocInv)
				begin
				      -- Process Location Unit Of Measure records
				       DECLARE  CURLUOM CURSOR FOR
					SELECT CAST(INTERNAL_LOC_UM AS VARCHAR) FROM LOCATION_UNIT_OF_MEASURE
					WHERE INTERNAL_LOCATION_INV = @iIntLocInv;

				      OPEN CURLUOM;

				      FETCH FROM CURLUOM INTO @internallocUM;

				      WHILE (@@FETCH_STATUS = 0)
					begin
						if (@internalLocUMs is null)
						begin
							set @internalLocUMs = ltrim(rtrim(@internallocUM));
						end
						else
						begin
						  set @internalLocUMs = @internalLocUMs + N';'+ ltrim(rtrim(@internallocUM));
						end;

						FETCH NEXT FROM CURLUOM INTO @internallocUM;
					        
					end;

				     	close curLUOM;

				     	deallocate curLUOM;
				

					UPDATE LOCATION_UNIT_OF_MEASURE
					SET  INTERNAL_LOCATION_INV = null
					WHERE
						INTERNAL_LOCATION_INV = @iIntLocInv;
				

				End
			else
			   Begin
				set @internalLocUMs = null;
			   End;

            if(@cPermanent <> N'Y' AND @cPermanent <> N'y')
           begin
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
				set  @dtAfterExpDate = NULL;
				set @cAdjustmentCompleted = N'Y';				
			end;
			end;
		end; -- end if deleting LocationInventory.
		if ((@dNewAllocQty <> 0.0
			OR @dNewInTransQty <> 0.0
			OR @dNewOnHandQty <> 0.0
			OR @dNewSuspQty <> 0.0 )
			OR @cPermanent = N'Y' OR @cPermanent = N'y')
		begin
			-- adjust the from side.
			-- Pass only part of the adjust information and retrieve 
			-- a number of output parameters.

			-- if this allocation result into -ve available qty then do not allow that
			if(@isNegativeAvailableAllowed =N'False')
			Begin
				If(
				(@fromLocationClass = N'Inventory' AND @cFromAllocEffect = N'+'  AND (@allocateIntransit =N'Y' OR @allocateIntransit =N'y') AND
				( @dInitOnHandQty + @dInitInTransQty - @dInitSuspQty - @dNewAllocQty) < 0) 
				OR
				(@fromLocationClass =N'Inventory' AND @cFromAllocEffect = N'+'AND (@allocateIntransit =N'N' OR @allocateIntransit =N'n') AND 
				( @dInitOnHandQty - @dInitSuspQty - @dNewAllocQty) < 0)
				OR 
				(@fromLocationClass =N'Inventory' AND @cFromOnHandEffect =N'-' AND @dNewOnHandQty < 0.0 AND @dNewInTransQty=0.0))
				begin
						
					set @stErrorMsg = N'MSG_INVVAL10: ' + dbo.RSCMfn_RtrvMsg(N'MSG_INVVAL10'); 		
					RAISERROR(@stErrorMsg , 18, 1);
					return -1;   
				End
			end;

			exec @iError = INV_UpdateFromLocInv
					@iIntLocInv,
					@dInitAllocQty, @dInitInTransQty, @dInitOnHandQty, @dInitSuspQty,
					@dNewAllocQty, @dNewInTransQty, @dNewOnHandQty, @dNewSuspQty, 
					@dOverrodeVolumePerItem, @dOverrodeWeightPerItem, 
					@stUserName,@fromLocInvAttributeId,
					@dtFromAgingDate output, @dtFromExpDate output, @dtFromManDate output, @dtFromRecDate output, @stFromInvSts output, @stFromItemColor output, @stFromItemDesc output, @stFromItemSize output, @stFromItemStyle output,
					@iRowCount output;
			if (@@ERROR <> 0) return -1; else if (@iError <> 0) return @iError;
			
			-- if the update was unsuccessful, some other process modified
			-- the LocationInventory record.  Increment the counter and try 
			-- again.
			if (@iRowCount <= 0)
				set @iNumOfLockFailures = @iNumOfLockFailures + 1;
			else
				begin
					set @dtAfterExpDate = @dtFromExpDate;
					set @cAdjustmentCompleted = N'Y';
				end;
		end; -- end if updating LocationInventory.
	end; -- end optimistic lock.
	
	-- if the adjustment was not completed, raise an error and return.
	if (@cAdjustmentCompleted is null)
	begin
		set @stErrorMsg = 
			N'MSG_INVENTORY05: ' + dbo.RSCMfn_RtrvMsg(N'MSG_INVENTORY05'); 				
		RAISERROR(@stErrorMsg , 18, 1);
		return -1;
	end; -- end if could not modify inventory.

	-- if the inventory was initially empty, process accordingly.
	if (@dInitAllocQty = 0.0
		and @dInitInTransQty = 0.0
		and @dInitOnHandQty = 0.0
		and @dInitSuspQty = 0.0)
	begin
		-- if we are dealing with a lot, insert the new record.
		if (@stLot is not null)
		begin

			-- existing empty location inventory will get selected for permanent location though lot is null
			-- hence we need to update lot on that record
			if(@cOriginalPermanent = N'Y' or @cOriginalPermanent = N'y')
			begin
				UPDATE LOCATION_INVENTORY 
					SET LOT = @stLot, 
					EXPIRATION_DATE = @dtExpDate
				WHERE INTERNAL_LOCATION_INV = @iIntLocInv;
			end;
			
			exec @iError = INV_ProcessLotInNewInventory @stFromLoc, @stLot, @stItem, @stCompany, 
					@stFromWhs, @dtExpDate, @stInventorySts,@argumentGroupId;
			if (@@ERROR <> 0) return -1; else if (@iError <> 0) return @iError;
			
		end; -- end if lot specified.
		
		if (@stFromContId is not null and (@stCntTrack = N'Y' or @stCntTrack = N'y'))
		begin
			UPDATE LOCATION_INVENTORY SET LOGISTICS_UNIT = @stFromContId 
			WHERE INTERNAL_LOCATION_INV = @iIntLocInv;
		end
		-- When cycle counting an empty location the container will be specified as recContId since the system is receiving the quantity
		else if (@stRecContID is not null and (@stCntTrack = N'Y' or @stCntTrack = N'y'))
		begin
			UPDATE LOCATION_INVENTORY SET LOGISTICS_UNIT = @stRecContID
			WHERE INTERNAL_LOCATION_INV = @iIntLocInv;
		end

		if (@fromLocInvAttributeId is not null and @fromLocInvAttributeId > 0)
		begin

			-- existing empty location inventory will get selected for permanent location. Set the inventory attributes id on the record
			if(@cOriginalPermanent = N'Y' or @cOriginalPermanent = N'y')
			begin
				UPDATE LOCATION_INVENTORY 
					SET LOC_INV_ATTRIBUTES_ID = @fromLocInvAttributeId
				WHERE INTERNAL_LOCATION_INV = @iIntLocInv;
			end;
			
		end; -- location inventory attributes id specified
		
	end; -- end if location was empty.

	if ((@stTransType = N'130' or @stTransType=N'140') and @stDefaultInvSts is not null)
		set @stInventorySts = @stDefaultInvSts;					


	-- if the inventory was emptied, execute additional logic.
	if (@dNewAllocQty = 0.0
		AND @dNewInTransQty = 0.0
		AND @dNewOnHandQty = 0.0
		AND @dNewSuspQty = 0.0)
	begin
		if (@stLot is not null
		    and (isnull(@cToOnHandEffect, N'!') <> N'+' or 
			(@stFromWhs <> @stToWhs and @stFromWhs is not null 
			and @stToWhs is not null)))
		begin
			exec @iError = INV_ProcessLotWhenEmptyingInv @stFromLoc, @stLot, @stItem, @stCompany, @stFromWhs, @stFromContId;
			if (@@ERROR <> 0) return -1; else if (@iError <> 0) return @iError;
		end;

		--Delete the overrides for location
		DELETE FROM LOCATION_UNIT_OF_MEASURE
		WHERE INTERNAL_LOCATION_INV = @iIntLocInv;
			 
		-- clear the inventorySts for history.
		set @stInventorySts = null;
	end; -- end if location emptied.
	
	--Set the FROM location INTERNAL_LOCATION_INV
	SET @fromIntLocInv = @iIntLocInv;

	--Set the FROM location USER_DEF1. This is an output variable; it doesn't get used in this proc, but still needs to be set here.
	SET @fromUserdef1 = @iUserdef1; -- JP3 Blake Becker 08/02/2024
	
	-- if decrementing the onHandQty, check for CycleCount Threshold 
	if (@cFromOnHandEffect = N'-')
	begin
		
		--get sum of all on hand qty for that location/item/company (sum of all license plates' and lot qty)
		SELECT @dTotalOnHandQty = ISNULL(SUM(LI.ON_HAND_QTY),0)
			  FROM LOCATION_INVENTORY LI,
	  			LOCATION LOC
			 WHERE LOC.LOCATION = LI.LOCATION
			   AND LOC.WAREHOUSE = LI.WAREHOUSE	
			   AND LI.LOCATION = @stFromLoc
			   AND LI.WAREHOUSE = @stFromWhs
			   AND LI.ITEM = @stItem
			   AND 
					((LI.COMPANY IS NULL AND @stCompany IS NULL)
					OR
					(LI.COMPANY = @stCompany));

		exec @iError = INV_CheckLocThreshold @stItem, @stItemDesc, @stCompany, @stLot,
								   @stFromLoc, @stFromWhs, @stFromContId, @fromLocInvAttributeId, 
								   @stWorkUnit, @dTotalOnHandQty, @stQuantityUm,
								   @stUserName;
		if (@@ERROR <> 0) return -1; else if (@iError <> 0) return @iError;
	end; -- end if decrementing onHandQty.	
		
	-- update the Location status.
	exec @iError = INV_UpdateLocation
			0,
			@stFromLoc, @stFromWhs, @stUserName,
			@dNewAllocQty, @dNewInTransQty, @dNewOnHandQty, @dNewSuspQty, 
			@cFromOnHandEffect,	@stCompany, @stItem, @stQuantityUm, @stLot,
			@stFromContId;	
	if (@@ERROR <> 0) return -1; else if (@iError <> 0) return @iError;

	-- set inventory attributes ID for history based on from attribute ID
	set @histFromLocInvAttributeId = @fromLocInvAttributeId;
	-- there are some instances where the from attribute ID may have been set to null; we still want to log the inventory attribute ID on history in this scenario, so check for it
	if (isnull(@histFromLocInvAttributeId, 0) = 0)
	begin 
		set @histFromLocInvAttributeId = @originalFromInvAttrId;
	end

	-- write TransactionHistory.
	exec @iError = INV_SaveHistInvChg
			0,
			@cForceOnHandZero, @cFromAllocEffect, @cFromInTransEffect, @cFromOnHandEffect, @cReversal, @cFromSuspEffect, @dQuantity, @dReferenceLine, @iInternalNum, @stCompany, @stFromContId, @stEquipmentType, @stInventorySts, @stItem, @stFromLoc, @stLot, @stQuantityUM, @stRecContID, @stReferenceID, @stReferenceType, @stTeam, @stTransType, @stUserDef1, @stUserDef2, @stUserDef3, @stUserDef4, @stUserDef5, @stUserDef6, @dUserDef7, @dUserDef8, @stUserName, @stFromWhs, @stWorkGroup, @stWorkType, @stWorkUnit,
			@stCompany, @stToWhs, @dInitAllocQty, @dInitInTransQty, @dInitOnHandQty, @dInitSuspQty, @stInitInvSts,
			@argumentGroupId,@dtAfterExpDate,@initExpDate,@histFromLocInvAttributeId,
			@cTransHistActive output;
	if (@@ERROR <> 0) return -1; else if (@iError <> 0) return @iError;
-- end INV_PickFromLocation


GO
