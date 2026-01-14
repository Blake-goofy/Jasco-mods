SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
 /*                  
 Mod   | Programmer | Date       | Modification Description                  
 --------------------------------------------------------------------                  
 BR02  | UV			| 09/26/2021 | Created this SP to navigate to respective DIF Incoming Message SP                 
 BR07  | IG			| 10/14/2021 | Added Incoming message from IBM MQ for Inventory Adjustment            
 BR08  | IG			| 11/09/2021 | Added Incoming message from IBM MQ for Inventory Sync         
 BR06  | IG			| 11/09/2021 | Added Incoming message from IBM MQ for Inventory Recall         
 BR04  | UV			| 11/14/2021 | Added incoming message from IBM MQ for Pick task complete and pick order status      
 BR04A | UV			| 03/22/2021 | Added incoming message from IBM MQ for Pick task update       
 BR05  | AV		    | 10/14/2021 | Added Incoming messages from IBM MQ for Order Complete and Order Status      
 EX23  | KA			| 07/13/2023 | Added 206 event id to update container status to 401 from 330    
 JP11  | Nash Kibler| 05/29/2025 | Added JP11_InventoryRecallAsrs to event 211   
*/                  
                
CREATE OR ALTER Procedure [dbo].[JPCI_IBMMQ_DIFIncomingMessage](                  
 @iMsgID int                  
)                  
AS                  
BEGIN                  
 -- SET NOCOUNT ON added to prevent extra result sets from                  
 -- interfering with SELECT statements.                  
 SET NOCOUNT ON;                  
 Declare @eventId numeric(9,0);                  
 DECLARE @jsonData nvarchar(max);                
                
 Select @eventId=EVENT_ID,@jsonData=DATA From DIF_INCOMING_MESSAGE with(nolock) Where MSG_ID = @iMsgID
                 
If(@eventId = 206)    
BEGIN    
 EXEC JPCI_EX23_UPDATE_401_STATUS  @jsonData    
 EXEC JPCI_EX23_PALLET_ORDER_MESSAGE_NEW @jsonData    
END    
            
--203 - INCOMING MESSAGES from IBM MQ for GTIN Received                  
--If(@eventId = 203)                  
--Begin                  
-- EXEC JPCI_BR02_GTIN_RECEIVED_DIFINCOMING @iMsgid, @jsonData                
                 
--END                
                
-- 201 - Incoming message from IBM MQ for Item Master failure                
ELSE IF(@eventId=201)                
BEGIn                 
 EXEC JPCI_BR01_ITEM_MASTER_FAILURE @iMsgId, @jsonData                
END                
                 
                
-- 202 - Incoming Message from IBM MQ for Receipt order failure                
--ELSE IF(@eventId=202)                
--BEGIN                
-- EXEC JPCI_BR02_RECEIPT_ORDER_FAILURE @iMsgId, @jsonData                
--END                
                
                
-- 204 - Incoming message from IBM MQ for Receipt order complete                
--ELSE IF(@eventId=204)                
--BEGIN                
-- EXEC JPCI_BR02_RECEIPT_ORDER_COMPLETE @iMsgId, @jsonData                
--END                
-- 205 - Incoming message from IBM MQ for Receipt order complete                
ELSE IF(@eventId=205)                
BEGIN                
 EXEC JPCI_BR03_INBOUND_ORDER_STATUS_DIFINCOMING @iMsgId, @jsonData                
END                
                
-- 204 - Incoming message from IBM MQ for Receipt order complete                
ELSE IF(@eventId=206)                
BEGIN                
 EXEC JPCI_BR03_INBOUND_ORDER_COMPLETE_DIFINCOMING @iMsgId, @jsonData                
END                
      
-- 209 - Incoming message from IBM MQ for Pallet Tote Arrival      
ELSE IF(@eventId=209)      
BEGIN      
 EXEC JPCI_BR05_PALLET_TOTE_ARRIVAL_DIFINCOMING @iMsgId, @jsonData      
END      
      
-- 210 - Incoming message from IBM MQ for Pallet Order Status      
ELSE IF(@eventId=210)      
BEGIN      
 EXEC JPCI_BR05_PALLET_ORDER_STATUS_DIFINCOMING @iMsgId, @jsonData      
END      
   
 -- 211 - Incoming message from IBM MQ for Inventory Adjustment complete
ELSE IF(@eventId=211)                
BEGIN 
    -- JP11 START
    DECLARE @USER AS NVARCHAR (50);
    DECLARE @GTIN AS NVARCHAR (50);
    DECLARE @QTY_CHANGED AS NUMERIC (9, 0);
    DECLARE @REASON AS NVARCHAR (50);
    DECLARE @JP11_REASON_CODE AS NVARCHAR (50) = (SELECT SYSTEM_VALUE FROM SYSTEM_CONFIG_DETAIL WHERE RECORD_TYPE = N'Technical' AND SYS_KEY = N'JP11_REASON_CODE');

    SELECT @USER = UserId,
           @GTIN = Gtin,
           @QTY_CHANGED = QuantityChanged,
           @REASON = Reason
    FROM OPENJSON (@jsonData, '$.InventoryAdjustment') WITH (UserId NVARCHAR (50), Gtin NVARCHAR (50), QuantityChanged INT, Reason NVARCHAR (50));

    IF @REASON = @JP11_REASON_CODE
       AND CHARINDEX(N'-', @QTY_CHANGED) > 0
        BEGIN
            EXECUTE JP11_InventoryRecallAsrs @iMsgId, @USER, @GTIN, @QTY_CHANGED;
        END
    ELSE
        BEGIN
            EXECUTE JPCI_BR07_INV_ADJ_DIFINCOMING @iMsgId, @jsonData;
        END
    -- JP11 END
END            
          
-- 212 - Incoming message from IBM MQ for Inventory Sync complete                
--ELSE IF(@eventId=212)                
--BEGIN                
-- EXEC JPCI_BR08_INV_SYNC_DIFINCOMING @iMsgId, @jsonData                
--END            
        
-- 214 - Incoming message from IBM MQ for Inventory Adjustment complete                
--ELSE IF(@eventId=214)                
--BEGIN                
-- EXEC JPCI_BR06_RECALL_TOTE_ARRIVAL @iMsgId, @jsonData                
--END               
            
-- 213 - Incoming message from IBM MQ for Inventory Adjustment complete                
--ELSE IF(@eventId=213)                
--BEGIN                
-- EXEC JPCI_BR06_INV_RECALLSTS_CREATE_WORK @iMsgId, @jsonData                
--END       
      
-- Pick task complete      
ELSE IF (@eventId=207)      
BEGIN      
 EXEC JPCI_BR04_PICK_TASK_COMPLETE_IN @iMsgId, @jsonData      
END      
      
-- Pick Order status      
ELSE IF (@eventId =208)      
BEGIN      
 EXEC JPCI_BR04_PICK_ORDER_STATUS_IN @iMsgId, @jsonData      
END      
      
ELSE IF (@eventId=217)      
BEGIN      
 EXEC JPCI_BR04_PICK_TASK_UPDATE_IN @iMsgId, @jsonData      
END      
                
--If EVENT_ID is not matched with above EVENT_ID values                
Else                
Begin                
 IF(@eventId IS NULL)                
 Begin                
  --Return DataTable Record with Valid or Not                
  Select N'No' as N'Valid',                
    N'MSG_ID is not matched in DIF_INCOMING_MESSAGE table' as N'ErrorMsg',                
    N'N' as N'InvokeAPI',                
    N'N' as N'LogAudit'                
 End                
 ELSE                
 Begin                
  --Return DataTable Record with Valid or Not                
  Select N'No' as N'Valid',                
    N'EventID is not matched in JPCI_IBMMQ_DIFIncomingMessage SP' as N'ErrorMsg',                
    N'N' as N'InvokeAPI',                
    N'N' as N'LogAudit'                
 End                
                
End                
                  
                      
END
GO
