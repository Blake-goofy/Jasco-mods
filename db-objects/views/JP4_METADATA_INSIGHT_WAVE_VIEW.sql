USE [JPCISCALEQA2025]
GO

/****** Object:  View [dbo].[JP4_METADATA_INSIGHT_WAVE_VIEW]    Script Date: 1/12/2026 1:33:46 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

/*
	Mod Number	| Programmer	| Date   	 | Modification Description
	-------------------------------------------------------------------- 
	184494		| NRJ			| 08/17/2016 | Created.	
	186029		| AU			| 09/16/2016 | Added WAVE_DATE_TIME_STARTED and WAVE_DATE_TIME_ENDED.
	202317      | SO            | 10/26/2017 | Added WAVE_STATUS.
	   JP4      | Blake Becker  | 01/12/2025 | Added CONTAINER_EST, PREVENT_RUN, and PREVENT_RELEASE.
*/

CREATE OR ALTER VIEW [dbo].[JP4_METADATA_INSIGHT_WAVE_VIEW] AS
WITH UM_Ranked
AS (SELECT ITEM,
           QUANTITY_UM,
           CONVERSION_QTY,
           ROW_NUMBER() OVER (PARTITION BY ITEM, QUANTITY_UM ORDER BY CONVERSION_QTY DESC) AS rn
    FROM dbo.ITEM_UNIT_OF_MEASURE
    WHERE QUANTITY_UM IN (N'EA', N'IP', N'CS')
          AND CONVERSION_QTY > 0),
 UM_Clean
AS (SELECT ITEM,
           QUANTITY_UM,
           CONVERSION_QTY
    FROM UM_Ranked
    WHERE rn = 1),
 UM_Fallback -- Pre-calculate fallback conversions per item
AS (SELECT UM1.ITEM,
           SD.TOTAL_QTY,
           MAX(UM1.CONVERSION_QTY) AS FALLBACK_CONVERSION
    FROM dbo.SHIPMENT_DETAIL AS SD
         INNER JOIN
         UM_Clean AS UM1
         ON UM1.ITEM = SD.ITEM
    WHERE SD.TOTAL_QTY > 0
          AND SD.CARRIER_TYPE IN (N'LTL', N'TL')
          AND SD.LAUNCH_NUM > 0
          AND UM1.CONVERSION_QTY <= SD.TOTAL_QTY
    GROUP BY UM1.ITEM, SD.TOTAL_QTY),
 EST
AS (SELECT SD.LAUNCH_NUM,
           SUM(SD.TOTAL_QTY / COALESCE (U.CONVERSION_QTY, FB.FALLBACK_CONVERSION, 1)) AS CONTAINER_EST
    FROM dbo.SHIPMENT_DETAIL AS SD
         LEFT OUTER JOIN
         UM_Clean AS U
         ON U.ITEM = SD.ITEM
            AND U.QUANTITY_UM = SD.USER_DEF1
         LEFT OUTER JOIN
         UM_Fallback AS FB
         ON FB.ITEM = SD.ITEM
            AND FB.TOTAL_QTY = SD.TOTAL_QTY
    WHERE SD.TOTAL_QTY > 0
          AND SD.CARRIER_TYPE IN (N'LTL', N'TL')
          AND SD.LAUNCH_NUM > 0
    GROUP BY SD.LAUNCH_NUM)
SELECT ls.INTERNAL_LAUNCH_NUM,
       ls.LAUNCH_NAME,
       ls.LAUNCH_FLOW,
       ls.LAUNCH_MODE,
       ls.TOTAL_SHIPMENTS,
       ls.TOTAL_LINES,
       ls.RELEASED,
       ls.CLOSED,
       ls.LAUNCH_DATE_TIME_STARTED AS WAVE_DATE_TIME_STARTED,
       ls.LAUNCH_DATE_TIME_ENDED AS WAVE_DATE_TIME_ENDED,
       ls.TOTAL_QTY,
       ls.CURRENT_LAUNCH_STEP,
       ls.LAST_LAUNCH_STEP,
       ls.WAREHOUSE,
       ls.LAUNCH_FILTER_NAME,
       ls.AUTO_RELEASE,
       ls.TOTAL_WEIGHT,
       ls.WEIGHT_UM,
       ls.TOTAL_VOLUME,
       ls.VOLUME_UM,
       ls.LAUNCH_COMMENT,
       ls.USER_DEF1,
       ls.USER_DEF2,
       ls.USER_DEF3,
       ls.USER_DEF4,
       ls.USER_DEF5,
       ls.USER_DEF6,
       ls.USER_DEF7,
       ls.USER_DEF8,
       ls.USER_STAMP,
       ls.PROCESS_STAMP,
       ls.DATE_TIME_STAMP,
       ls.WAVE_LABEL_STATUS,
       ls.LABEL_MASTER_ID,
       ls.LABOR_PLAN_EXEC_IN_PROGRESS,
       CASE WHEN (ls.LAUNCH_DATE_TIME_STARTED IS NULL
                  OR ls.CURRENT_LAUNCH_STEP IS NOT NULL) THEN N'Y' ELSE N'N' END AS ACTIVE,
       CASE WHEN (ls.LAUNCH_DATE_TIME_STARTED IS NOT NULL
                  AND ls.CURRENT_LAUNCH_STEP IS NULL
                  AND ls.RELEASED <> N'Y'
                  AND ls.LAST_LAUNCH_STEP <> N'Cancelled') THEN N'Y' ELSE N'N' END AS COMPLETED,
       CASE WHEN (ls.LAST_LAUNCH_STEP IS NOT NULL
                  AND ls.LAST_LAUNCH_STEP = N'Cancelled') THEN N'Y' ELSE N'N' END AS CANCELLED,
       CASE WHEN (ls.LAUNCH_DATE_TIME_STARTED IS NULL
                  OR ls.CURRENT_LAUNCH_STEP IS NOT NULL) THEN N'10' WHEN (ls.LAUNCH_DATE_TIME_STARTED IS NOT NULL
                                                                          AND ls.CURRENT_LAUNCH_STEP IS NULL
                                                                          AND ls.RELEASED <> N'Y'
                                                                          AND ls.LAST_LAUNCH_STEP <> N'Cancelled') THEN N'20' WHEN RELEASED = N'Y' THEN N'30' WHEN (ls.LAST_LAUNCH_STEP IS NOT NULL
                                                                                                                                                                    AND ls.LAST_LAUNCH_STEP = N'Cancelled') THEN N'40' ELSE NULL END AS WAVE_STATUS,
       EST.CONTAINER_EST AS CONTAINER_EST,
       N'N' AS PREVENT_RUN, -- Future dev
       N'N' AS PREVENT_RELEASE -- Future dev
FROM LAUNCH_STATISTICS AS ls
     LEFT OUTER JOIN
     EST
     ON EST.LAUNCH_NUM = ls.INTERNAL_LAUNCH_NUM;