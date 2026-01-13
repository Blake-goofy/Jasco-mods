SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*
	Mod Number	| Programmer	| Date   	| Modification Description
	--------------------------------------------------------------------
	9593		| RAB			| 08/14/02	| Created.
	10327		| RAB			| 03/04/03	| Return on zero quantity immediately.
	4415		| RAB			| 03/05/03	| Add userDef fields.
	9906		| RAB			| 03/13/03	| Passed inTransEffect to INV_ProcLocContsAndUms.
	10790		| RAB			| 03/20/03	| Add forceOnHandToZero.
	6888		| LJM			| 04/02/03	| Keep expiration dates consistent throughout inventory
	10876		| RAB			| 04/14/03	| Log information on invalid parameters.
	11870		| TBS			| 09/16/03	| Added Multi-Byte support.
	14842		| RAB			| 09/09/04	| Serial Number Tracking.
	16780		| TDL			| 09/07/05	| Force Recompile
	19167		| SAT			| 05/18/06	| License Plate Changes
	19166		| KSP			| 06/05/06	| License Plate Tracking
	16846		| DRK			| 08/02/08	| Resolved LotAutoFill and Expiration Date issue
	22534		| SMS			| 03/28/08	| Added @fromIntLocInv variable for Location UM Consolidation functionality
	27602		| YHR			| 06/20/08	| Modified parameter names so oracle and sql names will be same
	66433		| SSH			| 07/03/10	| Added parameters @fromLocInvAttributeId and @toLocInvAttributeId.
	75456		| NB			| 29/09/10	| Modifed not to call INV_PickSerialNumbers when doing -ve adjustement 
	86637       | MDL           | 08/01/11  | Added location inventory swap param
	184053		| MMM			| 08/02/16	| Fixed serial number linking issue when new attribute record is created as part of putaway - returned newly 
											  inserted attribute id from INV_PutIntoLocation procedure
	260752		| NRJ			| 11/09/20	| Modified to validate the serial numbers. 
	262192		| NRJ			| 12/22/20	| Added @stTransType to INV_PickSerialNumbers
	262192		| NRJ			| 01/05/20	| Added item and company to INV_PickSerialNumbers.
	263598		| NRJ			| 02/09/21	| Modified to throw error message when serial numbers are not passed for Pick/Putaway transactions.
	264021		| NRJ			| 02/12/21	| Modified to include 120 and 460 transaction types for serial number checks.
	264021		| NRJ			| 02/16/21	| Modified to throw error message only when toLoc is shipping dock for transaction type 140/120.
	JP3			| Blake Becker	| 08/02/2024| Passing UD1 from INV_PickFromLocation to INV_PutIntoLocation
	Adjusts inventory based on supplied information.
	
	Parameters
		All adjustment information passed from business logic.
*/

-- #DEFINE WMW.JSharp.General com.pronto.general.Constants Constants;


CREATE OR ALTER   PROCEDURE [dbo].[INV_AdjustInv](
	@cFromAllocEffect nchar(1), -- SYSTEM_CREATED used to set char type
	@cFromInTransEffect nchar(1),
	@cFromOnHandEffect nchar(1),
	@cFromSuspEffect nchar(1),
	@cReversal nchar(1),
	@cToAllocEffect nchar(1),
	@cToInTransEffect nchar(1),
	@cToOnHandEffect nchar(1),
	@cToSuspEffect nchar(1),
	@dFromContQty numeric(19,5),
	@dQuantity numeric(19,5),
	@dReferenceLine numeric(19,5),
	@iInternalNum numeric(9),
	@stCompany nvarchar(25),
	@stEquipmentType nvarchar(25),
	@stExpDate nvarchar(50), -- LPDateTime
	@cForceOnHandZero nchar(1),
	@stFromContId nvarchar(50),
	@stFromLoc nvarchar(25),	
	@stFromWhs nvarchar(25),
	@stInventorySts nvarchar(50),
	@stItem nvarchar(50),
	@stItemDesc nvarchar(100),
	@stLot nvarchar(25),
	@stManDate nvarchar(50), -- LPDateTime
	@stQuantityUM nvarchar(25),
	@stRecContID nvarchar(25),
	@FromParentLogisticsUnit nvarchar(50),
	@ToParentLogisticsUnit nvarchar(50),
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
    @fromLocInvAttributeId numeric(9) = NULL,
    @toLocInvAttributeId numeric(9) = NULL,
	@isNegativeAvailableAllowed bit = false)

AS
	SET NOCOUNT ON;

	-- local variables
	declare @cTransHistActive nvarchar(250);
	declare @dOverrodeVolumePerItem numeric(28,5);
	declare @dOverrodeWeightPerItem numeric(28,5);
	declare @dtExpDate datetime;
	declare @dtFromAgingDate datetime;
	declare @dtFromExpDate datetime;
	declare @dtFromManDate datetime;
	declare @dtFromRecDate datetime;
	declare @dtManDate datetime;
	declare @iError int;
	declare @stErrorMsg nvarchar(2000);
	declare @stFromInvSts nvarchar(50);
	declare @stFromItemColor nvarchar(25);
	declare @stFromItemDesc nvarchar(100);
	declare @stFromItemSize nvarchar(25);
	declare @stFromItemStyle nvarchar(25);
	declare @stFromToLoc nvarchar(2000);
	declare @stFromToWhs nvarchar(2000);
	declare @sernCount int;
	declare @stInternalLocUMs nvarchar(100);
	declare @fromIntLocInv numeric(9); --Needed for location consolidation
	declare @fromUserdef1 nvarchar(25); --Needed for decant UD1
		
	
	-- return immediately if invalid parameters are given.
	if (@dQuantity is null
		or @dQuantity = 0.0
		or (@stFromLoc is null
			and @stToLoc is null)
		or @stItem is null)
	begin
		-- log an audit to record that inventory was called in
		-- an unexpected way.
		set @stErrorMsg = 
			N'MSG_INVENTORY08: ' + dbo.RSCMfn_RtrvMsg(N'MSG_INVENTORY08'); 
		set @stFromToLoc = isnull(@stFromLoc,N'null') + N' / ' + 
						   isnull(@stToLoc,N'null');
		set @stFromToWhs = isnull(@stFromWhs,N'null') + N' / ' + 
						   isnull(@stToWhs,N'null');
		exec ADT_LogAudit 
				N'INV_AdjustInv',							-- procName
				null,										-- returnValue
				@stErrorMsg,								-- message
				N'transType: ', @stTransType,				-- parm1
				N'item: ', @stItem,							-- parm2
				N'company: ', @stCompany,					-- parm3
				N'lot: ', @stLot,							-- parm4
				N'from / to loc: ', @stFromToLoc,			-- parm5
				N'from / to warehouse: ', @stFromToWhs,		-- parm6
				N'quantity: ', @dQuantity,					-- parm7
				N'quantityUm: ', @stQuantityUm,				-- parm8
				N'referenceId: ', @stReferenceId,			-- parm9
				N'referenceLine: ', @dReferenceLine,			-- parm10
				@stUserName,								-- userName
				@stFromWhs;									-- warehouse
		return;
	end; -- end if no invalid parameters.
	
	-- convert any LPDateTime parameters to their datetime values.
	set @dtExpDate = dbo.DHfn_TransToSQLDate(@stExpDate);
	set @dtManDate = dbo.DHfn_TransToSQLDate(@stManDate);
	
	if(@fromLocInvAttributeId = 0)
		set @fromLocInvAttributeId = NULL;
		
	if(@toLocInvAttributeId = 0)
		set @toLocInvAttributeId = NULL;

	if(@argumentGroupId is null)
	BEGIN
		declare @serialNumTracking int;
		set @serialNumTracking=(SELECT ISNULL(SERIAL_NUM_TRACKING, 0) FROM ITEM 
								WHERE ITEM = @stItem 
								AND (COMPANY = @stCompany OR COMPANY IS NULL));



		IF((@stTransType=N'120' OR @stTransType = N'130' OR @stTransType=N'140' OR @stTransType=N'460') AND @serialNumTracking=7)			
		BEGIN	
					
			IF(@stTransType=N'140' OR @stTransType=N'120')
			BEGIN
				declare @locationClass nvarchar(25);
				set @locationClass =(SELECT LOCATION_CLASS FROM LOCATION WHERE LOCATION=@stToLoc AND WAREHOUSE=@stToWhs);

				--raise error only if to location is shipping dock for transaction type 140/120
				IF(@locationClass =N'Shipping Dock')
				BEGIN
					RAISERROR(N'Serial numbers are not specified on the transaction. Transaction type:%s', 18, 1,@stTransType); 
					return -1;
				END
			END
			ELSE
			BEGIN
				RAISERROR(N'Serial numbers are not specified on the transaction. Transaction type:%s', 18, 1,@stTransType); 
				return -1;
			END
		END
	END
		
	-- pick any serial numbers.
	-- last char with "-" , so as to inform INV_AdjustInv that it is a -ve adjustment with entire LP 
	if (@argumentGroupId is not null 
		and substring(@argumentGroupId,len(@argumentGroupId),1) <> N'-'
	    and @cFromOnHandEffect = N'-')	    
	begin
		
		exec @iError = INV_ValidateSerialNums @dQuantity,@stCompany,@stFromContId,@stFromLoc,@stFromWhs,@stItem,@stLot,@stRecContID,@stTransType,@argumentGroupId,@fromLocInvAttributeId;
		if (@iError <> 0) return @iError;

		exec @iError = INV_PickSerialNumbers @argumentGroupId,@stTransType,@stItem,@stCompany, @sernCount output;
		if (@iError <> 0) return @iError;
	end; -- end if picking

		
	-- only adjust the from side if necessary. 
	if (@cFromOnHandEffect = N'-' -- cannot increment from onHandQty!
		or @cFromInTransEffect = N'+' or @cFromInTransEffect = N'-'
		or @cFromAllocEffect = N'+' or @cFromAllocEffect = N'-'
		or @cFromSuspEffect	= N'+' or @cFromSuspEffect	= N'-')
	begin
		exec @iError = INV_PickFromLocation
				@cForceOnHandZero, @cFromAllocEffect, @cFromInTransEffect, @cFromOnHandEffect, @cFromSuspEffect,@cToInTransEffect,@cToOnHandEffect, @cReversal,@dOverrodeVolumePerItem, @dOverrodeWeightPerItem, @dQuantity, @dReferenceLine, @dtExpDate, @dtManDate, @iInternalNum, @stCompany, @stEquipmentType, @stFromContId, @stFromLoc, @stFromWhs, @stInventorySts, @stItem, @stItemDesc, @stLot, @stQuantityUM, @stRecContID, @FromParentLogisticsUnit, @stReferenceID, @stReferenceType, @stTeam, @stTransType, @stUserDef1, @stUserDef2, @stUserDef3, @stUserDef4, @stUserDef5, @stUserDef6, @dUserDef7, @dUserDef8, @stUserName, @stWorkGroup, @stWorkType, @stWorkUnit,
				@argumentGroupId, @stToWhs, @fromLocInvAttributeId,@isNegativeAvailableAllowed,
				@dtFromAgingDate output, @dtFromExpDate output, @dtFromManDate output, @dtFromRecDate output, @stFromInvSts output, @stFromItemColor output, @stFromItemDesc output, @stFromItemSize output, @stFromItemStyle output,
				@cTransHistActive output, @stInternalLocUMs output, @fromIntLocInv output, @fromUserdef1 output;-- JP3 Blake Becker 08/02/2024
		if (@@ERROR <> 0) return -1; else if (@iError <> 0) return @iError;
	end; -- end if from qty affected.
		
	-- only adjust the to side if necessary. 
	if (@cToOnHandEffect = N'+' -- cannot decrement to onHandQty!
		or @cToInTransEffect = N'+' or @cToInTransEffect = N'-'
		or @cToAllocEffect = N'+' or @cToAllocEffect = N'-'
		or @cToSuspEffect = N'+' or @cToSuspEffect = N'-')
	begin
		exec @iError = INV_PutIntoLocation
				@cForceOnHandZero, @cReversal, @cToAllocEffect, @cToInTransEffect, @cToOnHandEffect, @cToSuspEffect, @dOverrodeVolumePerItem, @dOverrodeWeightPerItem, @dQuantity, @dReferenceLine, @dtExpDate, @dtManDate, @iInternalNum, @stCompany, @stEquipmentType, @stInventorySts, @stItem, @stItemDesc, @stLot, @stQuantityUM, @stRecContID, @ToParentLogisticsUnit, @stReferenceID, @stReferenceType, @stTeam, @stToContId, @stToLoc, @stToWhs, @stTransType, @stUserDef1, @stUserDef2, @stUserDef3, @stUserDef4, @stUserDef5, @stUserDef6, @dUserDef7, @dUserDef8, @stUserName, @stWorkGroup, @stWorkType, @stWorkUnit,
				@argumentGroupId,
				@dtFromAgingDate, @dtFromExpDate, @dtFromManDate, @dtFromRecDate, @stFromInvSts, @stFromItemColor, @stFromItemDesc, @stFromItemSize, @stFromItemStyle,
				@cTransHistActive, @stInternalLocUMs, @fromIntLocInv, @fromUserdef1,
				@isNegativeAvailableAllowed, @toLocInvAttributeId output;
		if (@@ERROR <> 0) return -1; else if (@iError <> 0) return @iError;
	end; -- end if to qty affected.

	-- put any serial numbers.
	if (@argumentGroupId is not null
	    and (@cFromOnHandEffect <> N'-' or @sernCount > 0)
	    and @cToOnHandEffect = N'+')
	begin

		exec @iError = INV_PutSerialNumbers
			@argumentGroupId, @stToLoc, @stToWhs, @stItem, @stCompany, @stLot, @stToContId,@toLocInvAttributeId;
		if (@iError <> 0) return @iError;
	end; -- end if picking serial numbers.



GO
