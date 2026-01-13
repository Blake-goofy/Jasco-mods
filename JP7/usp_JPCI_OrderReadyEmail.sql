SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/*
 Mod     | Programmer    | Date       | Modification Description
 --------------------------------------------------------------------
 JP7     | Blake Becker  | 01/23/2025 | Created.
 JP7     | Blake Becker  | 01/28/2025 | Added process history.
 JP7     | Blake Becker  | 01/31/2025 | Fixed location on table.
 JP7     | Nash Kibler   | 05/12/2025 | Fixed location on table. Now we should get the latest location from Transaction History. 
*/

ALTER PROCEDURE [dbo].[JP7_OrderReadyEmail] (@INTERNAL_SHIPMENT_NUM NUMERIC (9,0)) AS

/*
NOTES
--------------------------------------------------------------------
Called by SHIPMENT_HEADER_A_U
*/

DECLARE @vRecipients NVARCHAR(max) = N''
DECLARE @copyrecipList NVARCHAR(max) = N''
DECLARE @blindCopyRecipList NVARCHAR(max) = N''
DECLARE @requester NVARCHAR(max)
DECLARE @vBody NVARCHAR(max)
DECLARE @termBody NVARCHAR(max)
DECLARE @shipID NVARCHAR(35)
DECLARE @vSubject NVARCHAR(max)
DECLARE @date NVARCHAR(35) = CONVERT(DATE, GETUTCDATE() at time zone N'UTC' at time zone N'central standard time')

--Declaring the Variables for Process History related ones                  
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
,@cProcHistActive NVARCHAR(2) = NULL -- future use


SELECT
	@shipID = SHIPMENT_ID
	,@vRecipients = SHIP_TO_EMAIL_ADDRESS
	,@requester = SHIP_TO_NAME
	,@stWarehouse = warehouse
FROM
	SHIPMENT_HEADER
WHERE
	INTERNAL_SHIPMENT_NUM = @INTERNAL_SHIPMENT_NUM


SET @vSubject = N'Order confirmed - ' + @shipID
SET @termBody = 
N'<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Order confirmed</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            margin: 20px;
        }
        .container {
            max-width: 600px;
            margin: auto;
            text-align: left;
        }
        .title {
            font-size: 24px;
            font-weight: bold;
        }
        .content {
            font-size: 14px;
            margin-top: 20px;
        }
    </style>
</head>
<body>
    <div class="container">
        <p class="title">Order confirmed</p>
        <p class="content"><strong>To:</strong> ' + @requester + N'</p>
        <p class="content"><strong>Date:</strong> ' + @date + N'</p>
        <p class="content"><strong>Shipment ID:</strong> ' + @shipID + N'</p>
		<p class="content">Your order is ready for pick up at the location listed below.</p>
		<br>
    </div>
'
DECLARE @orderTable NVARCHAR(MAX) = N'
	<table border="1" cellpadding="5" style="margin: auto; text-align: center; border-collapse: collapse; width: 80%; min-width: 600px; max-width: 800px;">
		<tr>
		    <th>Item</th>
		    <th>Description</th>
		    <th>Quantity</th>
		    <th>Location</th>
		</tr>';

DECLARE @tableXML NVARCHAR(MAX) = CONVERT(NVARCHAR (MAX),(
	SELECT 
		'', SC.ITEM AS 'td'
		,'', DESCRIPTION AS 'td'
		,'', SUM(CONVERT(INT, SC.QUANTITY)) AS 'td'
		,'', TH.LOCATION  AS 'td'
FROM SHIPPING_CONTAINER SC
	LEFT JOIN ITEM I ON I.ITEM = SC.ITEM
	LEFT JOIN (SELECT 
				TH.LOCATION 
				,TH.CONTAINER_ID
				,NUM = ROW_NUMBER() OVER(PARTITION BY TH.CONTAINER_ID ORDER BY TH.ACTIVITY_DATE_TIME DESC)
				FROM TRANSACTION_HISTORY TH  WHERE DIRECTION = N'To' AND TH.LOCATION IS NOT NULL
				GROUP BY TH.CONTAINER_ID ,TH.LOCATION ,TH.ACTIVITY_DATE_TIME
				) TH ON TH.CONTAINER_ID = SC.PARENT_CONTAINER_ID 
	WHERE convert(nvarchar,SC.INTERNAL_SHIPMENT_NUM) = @INTERNAL_SHIPMENT_NUM AND SC.ITEM IS NOT NULL AND TH.NUM = 1
	GROUP BY  SC.ITEM, DESCRIPTION, TH.LOCATION
	ORDER BY SC.ITEM
	FOR XML PATH ('tr')))

SET @vBody = @termBody + @orderTable + @tableXML + '</table></center></body></html>'

EXEC msdb.dbo.sp_send_dbmail
    @profile_name = 'JascoDBMail'
   ,@recipients = @vRecipients
   ,@copy_recipients = @copyrecipList
   ,@body = @vBody
   ,@body_format = 'HTML'
   ,@subject = @vSubject

SET @stProcess = N'Email sent'
SET @stAction = N'50' -- confirmation
SET @stIdentifier1 = @shipID
SET @stMessage = CONCAT(N'Confirmation email sent for ', @shipID,  N' to ', @vRecipients)
SET @stProcessStamp = N'usp_JPCI_OrderReadyEmail'
SET @stUserName = N'ILSSRV'

EXEC HIST_SaveProcHist @stProcess
	,@stAction
	,@stIdentifier1
	,@stIdentifier2
	,@stIdentifier3
	,@stIdentifier4
	,@stMessage
	,@stProcessStamp
	,@stUserName
	,@stWarehouse
	,@cProcHistActive