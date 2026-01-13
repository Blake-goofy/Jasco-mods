## Overview
Two database objects were added for this mod:
- [`SHIPMENT_HEADER_A_U`](https://github.com/Blake-goofy/Jasco-mods/blob/main/db-objects/triggers/SHIPMENT_HEADER_A_U.sql) (trigger)
- [`usp_JPCI_OrderReadyEmail`](https://github.com/Blake-goofy/Jasco-mods/blob/main/db-objects/stored-procedures/usp_JPCI_OrderReadyEmail.sql) (stored procedure)

This is the same trigger file modified in JP5 and JP6. JP7 adds functionality to automatically send confirmation emails to internal employees when their orders are ready for pickup.

## Background
Jasco employees frequently place orders for company products to be picked up on-site rather than shipped off-campus. Previously, employees had no automated way to know when their orders were staged and ready for pickup. This mod sends a friendly email notification as soon as the order reaches the "Loading Pending" status, allowing employees to immediately retrieve their orders from the on-site pickup location.

## Business Logic

### Trigger Logic (SHIPMENT_HEADER_A_U)
- **Trigger condition**: Fires when the `TRAILING_STS` (trailing status) field is updated on a shipment.
- **Status check**: Only processes shipments where:
  - Old status is **less than 650** (before Loading Pending)
  - New status is **between 650 and 900** (Loading Pending through Closed, inclusive)
- **Email eligibility**: Only sends email if:
  - The `SHIP_TO_EMAIL_ADDRESS` contains `byjasco.com` (internal employee)
  - The `CARRIER` is one of: `SAMP` (Sample), `P/U` (Pick Up), or `BYJC` (ByJasco)
- **Action**: Calls the stored procedure `usp_JPCI_OrderReadyEmail` with the shipment's internal number.

### Email Generation (usp_JPCI_OrderReadyEmail)
The stored procedure generates and sends an HTML-formatted email containing:

#### Email Header Information
- **To**: Recipient name from `SHIP_TO_NAME`
- **Date**: Current date in Central Time
- **Shipment ID**: The order number
- **Subject**: "Order confirmed - [Shipment ID]"

#### Order Details Table
An HTML table displaying:
- **Item**: The product item number
- **Description**: Product description
- **Quantity**: Total quantity ordered (summed if item appears in multiple containers)
- **Location**: The warehouse location where the item is staged (retrieved from the most recent transaction history)

#### Email Delivery
- Uses SQL Server's `sp_send_dbmail` with the `JascoDBMail` profile
- Sends to the email address specified in `SHIP_TO_EMAIL_ADDRESS`
- Formatted as HTML for better readability

## Process History Logging
The stored procedure logs each email sent to the `PROCESS_HISTORY` table:
- **PROCESS**: "Email sent"
- **ACTION**: 50 (Confirmation)
- **IDENTIFIER1**: Shipment ID
- **MESSAGE**: Details showing the shipment ID and recipient email (e.g., "Confirmation email sent for SHIP123 to john.doe@byjasco.com")
- **PROCESS_STAMP**: "usp_JPCI_OrderReadyEmail"
- **USER_STAMP**: "ILSSRV" (system user)

This provides an audit trail of all confirmation emails sent to employees.

## Visual
### Email example
![Email example](https://raw.githubusercontent.com/Blake-goofy/Jasco-mods/main/images/JP7-email.png)