# JP2 Case Label Customers (ODWS) Mod

## Overview
This mod provides an Override Data Wave Step (ODWS) that drives case-label behavior for a controlled list of customers. It uses a generic configuration list (stored in `GENERIC_CONFIG_DETAIL`) to identify customers that require case labels, and then the ODWS stored procedure performs two actions:

1. Apply a flag to shipments (`CUSTOMER_CATEGORY7`) for listed customers so VAS criteria can detect them and ensure parent/child labels are printed before containers are closed.
2. Convert PL allocations to CS allocations so each case (CS) has a unique UCC-128 identifier.

This approach avoids hard-coding customer lists in code and lets operations add/remove customers via the generic config UI.

## How it works
- The ODWS (Override Data Wave Step) calls the stored procedure `JP2_ODWS_AllocationRequestModify` to perform the changes. See the example ODWS screenshot below.
- The procedure checks `GENERIC_CONFIG_DETAIL` for customers on the case-label list, updates `SHIPMENT_HEADER.CUSTOMER_CATEGORY7` for matching shipments, then updates `SHIPMENT_ALLOC_REQUEST` converting PL -> CS where a CS UOM exists. It logs successes and warnings to process history and uses audit logging on errors.

### ODWS (stored proc caller)
![ODWS calling stored proc](https://raw.githubusercontent.com/Blake-goofy/Jasco-mods/main/images/JP2-ODWS.png)

### Case-label customer list (generic config)
This is an example of the `GENERIC_CONFIG_DETAIL` maintenance screen where operations can control which customers receive case labels.
![Case label customers list](https://raw.githubusercontent.com/Blake-goofy/Jasco-mods/main/images/JP2-Case-label-customers.png)

### VAS criteria
The `CUSTOMER_CATEGORY7` flag is used in VAS criteria to trigger parent/child label printing and any other value-added services required for those shipments.
![VAS criteria example](https://raw.githubusercontent.com/Blake-goofy/Jasco-mods/main/images/JP2-VAS-criteria.png)

### Installation note
Make sure to add the history process `JP2_AllocationRequestModify`
