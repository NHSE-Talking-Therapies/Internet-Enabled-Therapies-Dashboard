IF OBJECT_ID ('[MHDInternal].[TEMP_TTAD_IET_TypeAndDuration]') IS NOT NULL DROP TABLE [MHDInternal].[TEMP_TTAD_IET_TypeAndDuration]
SELECT  
    i.PathwayID
    ,i.IntEnabledTherProg
	,i.IntegratedSoftwareInd
    ,SUM(DurationIntEnabledTher) AS DurationIntEnabledTher
INTO [MHDInternal].[TEMP_TTAD_IET_TypeAndDuration]
FROM [mesh_IAPT].[IDS205internettherlog] i
INNER JOIN [mesh_IAPT].[IsLatest_SubmissionID] l ON i.[UniqueSubmissionID] = l.[UniqueSubmissionID] AND i.[AuditId] = l.[AuditId]
WHERE l.IsLatest = 1 --and Person_ID='T8EP9KH523L4Z3J'
GROUP BY i.PathwayID, i.IntEnabledTherProg, i.IntegratedSoftwareInd


DECLARE @PeriodStart DATE
DECLARE @PeriodEnd DATE 
--For refreshing, the offset for getting the period start and end should be -1 to get the latest refreshed month
SET @PeriodStart = (SELECT DATEADD(MONTH,-1,MAX([ReportingPeriodStartDate])) FROM [mesh_IAPT].[IsLatest_SubmissionID])
SET @PeriodEnd = (SELECT eomonth(DATEADD(MONTH,-1,MAX([ReportingPeriodEndDate]))) FROM [mesh_IAPT].[IsLatest_SubmissionID])

--The offset needs to be set for September 2020 (e.g. @PeriodStart -30 = -31 which is the offset of September 2020)
DECLARE @Offset int
SET @Offset=-31

SET DATEFIRST 1

PRINT @PeriodStart
PRINT @PeriodEnd

IF OBJECT_ID ('[MHDInternal].[TEMP_TTAD_IET_Base]') IS NOT NULL DROP TABLE [MHDInternal].[TEMP_TTAD_IET_Base]
SELECT DISTINCT
	CAST(DATENAME(m, l.ReportingPeriodStartDate) + ' ' + CAST(DATEPART(yyyy, l.ReportingPeriodStartDate) AS VARCHAR) AS DATE) as Month
    ,l.ReportingPeriodStartDate
	,l.ReportingPeriodEndDate
	,r.PathwayID

	,r.ReferralRequestReceivedDate
	,r.Assessment_FirstDate
	,r.TherapySession_FirstDate
	,r.TherapySession_SecondDate
	,r.ServDischDate

	--Wait Times
	,DATEDIFF(DD,r.ReferralRequestReceivedDate,r.Assessment_FirstDate) AS WaitRefToFirstAssess
	,DATEDIFF(DD,r.ReferralRequestReceivedDate,r.TherapySession_FirstDate) AS WaitRefToFirstTherapy
	,DATEDIFF(DD,r.TherapySession_FirstDate,r.TherapySession_SecondDate) AS WaitFirstTherapyToSecondTherapy
		
	--Number of Appointments
    ,r.InternetEnabledTherapy_Count

    --Type of IET
	--,i.IntEnabledTherProg
	,CASE WHEN (i.IntEnabledTherProg LIKE 'SilverCloud%' OR i.IntEnabledTherProg LIKE  'Slvrcld%' ) THEN 'SilverCloud'
		WHEN (i.IntEnabledTherProg LIKE 'Mnddstrct%' OR i.IntEnabledTherProg LIKE 'Minddistrict%') THEN 'Minddistrict'
		WHEN i.IntEnabledTherProg LIKE 'iCT%' THEN 'iCT'
		WHEN i.IntEnabledTherProg LIKE 'OCD%' THEN 'OCD-NET'
		WHEN i.IntEnabledTherProg IS NULL THEN 'No IET'
		ELSE i.IntEnabledTherProg
		END IntEnabledTherProg

	--Therapist Time
	,i.DurationIntEnabledTher

	--Integration Engine Flag
	,i.IntegratedSoftwareInd

	--Reasons for Ending Treatment
	,r.EndCode
	,CASE WHEN r.EndCode='' THEN 'Referred but not seen/Seen but not taken on for a course of treatment/Seen and taken on for a course of treatment'
		WHEN r.EndCode='50' THEN 'Not assessed'	
		WHEN r.EndCode='10' THEN 'Not suitable for IAPT service - no action taken or directed back to referrer'
		WHEN r.EndCode='11'	THEN 'Not suitable for IAPT service - signposted elsewhere with mutual agreement of patient'
		WHEN r.EndCode='12' THEN 'Discharged by mutual agreement following advice and support'
		WHEN r.EndCode='13' THEN 'Referred to another therapy service by mutual agreement'
		WHEN r.EndCode='14'	THEN 'Suitable for IAPT service, but patient declined treatment that was offered'
		WHEN r.EndCode='16' THEN 'Incomplete Assessment (Patient dropped out)'
		WHEN r.EndCode='17' THEN 'Deceased (Seen but not taken on for a course of treatment)'
		WHEN r.EndCode='95' THEN 'Not Known (Seen but not taken on for a course of treatment)'
		WHEN r.EndCode='46' THEN 'Mutually agreed completion of treatment'
		WHEN r.EndCode='47' THEN 'Termination of treatment earlier than Care Professional planned'
		WHEN r.EndCode='48' THEN 'Termination of treatment earlier than patient requested'
		WHEN r.EndCode='49' THEN 'Deceased (Seen and taken on for a course of treatment)'
		WHEN r.EndCode='96' THEN 'Not Known (Seen and taken on for a course of treatment)'
		ELSE 'Missing/invalid'
		END AS EndCodeDescription

    --Clinical Outcomes	
	,CASE WHEN (r.ServDischDate BETWEEN l.ReportingPeriodStartDate AND l.ReportingPeriodEndDate) AND r.CompletedTreatment_Flag = 'True' AND r.Recovery_Flag = 'True' 
		AND r.PathwayID IS NOT NULL THEN 1 ELSE 0 
	END AS CompTreatFlagRecFlag	--Flag for recovery, where the discharge date is within the reporting period, completed treatment flag is true and recovery flag is true
	,CASE WHEN (r.ServDischDate BETWEEN l.ReportingPeriodStartDate AND l.ReportingPeriodEndDate) AND r.CompletedTreatment_Flag = 'True' AND r.NotCaseness_Flag = 'True' 
		AND r.PathwayID IS NOT NULL THEN 1 ELSE 0 
	END AS CompTreatFlagNotCasenessFlag	--Flag for not caseness, where the discharge date is within the reporting period, completed treatment flag is true and not caseness flag is true
	,CASE WHEN (r.ServDischDate BETWEEN l.ReportingPeriodStartDate AND l.ReportingPeriodEndDate) AND r.CompletedTreatment_Flag = 'True' AND r.ReliableImprovement_Flag = 'True' 
		AND r.PathwayID IS NOT NULL THEN 1 ELSE 0
	END AS CompTreatFlagRelImpFlag	--Flag for reliable improvement, where the discharge date is within the reporting period, completed treatment flag is true and reliable improvement flag is true
	,CASE WHEN (r.ServDischDate BETWEEN l.ReportingPeriodStartDate AND l.ReportingPeriodEndDate) AND r.CompletedTreatment_Flag = 'True' AND r.ReliableImprovement_Flag = 'True' 
		AND r.Recovery_Flag = 'True' AND r.PathwayID IS NOT NULL THEN 1 ELSE 0
	END AS CompTreatFlagRelRecFlags	--Flag for reliable improvement and recovery, where the discharge date is within the reporting period, completed treatment flag is true and reliable improvement flag is true
	,CASE WHEN (r.ServDischDate BETWEEN l.ReportingPeriodStartDate AND l.ReportingPeriodEndDate) AND r.CompletedTreatment_Flag = 'True' 
		AND r.PathwayID IS NOT NULL THEN 1 ELSE 0
	END AS CompTreatFlag --Flag for completed treatment flag, where the discharge date is within the reporting period
    
    --Problem Descriptor
	,CASE WHEN r.PresentingComplaintHigherCategory = 'Depression' OR r.[PrimaryPresentingComplaint] = 'Depression' THEN 'F32 or F33 - Depression'
		WHEN r.PresentingComplaintHigherCategory = 'Unspecified' OR r.[PrimaryPresentingComplaint] = 'Unspecified'  THEN 'Unspecified'
		WHEN r.PresentingComplaintHigherCategory = 'Other recorded problems' OR r.[PrimaryPresentingComplaint] = 'Other recorded problems' THEN 'Other recorded problems'
		WHEN r.PresentingComplaintHigherCategory = 'Other Mental Health problems' OR r.[PrimaryPresentingComplaint] = 'Other Mental Health problems' THEN 'Other Mental Health problems'
		WHEN r.PresentingComplaintHigherCategory = 'Invalid Data supplied' OR r.[PrimaryPresentingComplaint] = 'Invalid Data supplied' THEN 'Invalid Data supplied'
		WHEN (r.PresentingComplaintHigherCategory = 'Anxiety and stress related disorders (Total)' OR r.[PrimaryPresentingComplaint] = 'Anxiety and stress related disorders (Total)') AND (r.PresentingComplaintLowerCategory = '83482000 Body Dysmorphic Disorder' OR [SecondaryPresentingComplaint] = '83482000 Body Dysmorphic Disorder') THEN '83482000 Body Dysmorphic Disorder'
		WHEN (r.PresentingComplaintHigherCategory = 'Anxiety and stress related disorders (Total)' OR r.[PrimaryPresentingComplaint] = 'Anxiety and stress related disorders (Total)') AND (r.PresentingComplaintLowerCategory = 'F400 - Agoraphobia' OR [SecondaryPresentingComplaint] = 'F400 - Agoraphobia') THEN 'F400 - Agoraphobia'
		WHEN (r.PresentingComplaintHigherCategory = 'Anxiety and stress related disorders (Total)' OR r.[PrimaryPresentingComplaint] = 'Anxiety and stress related disorders (Total)') AND (r.PresentingComplaintLowerCategory = 'F401 - Social phobias' OR [SecondaryPresentingComplaint] = 'F401 - Social phobias') THEN 'F401 - Social Phobias'
		WHEN (r.PresentingComplaintHigherCategory = 'Anxiety and stress related disorders (Total)' OR r.[PrimaryPresentingComplaint] = 'Anxiety and stress related disorders (Total)') AND (r.PresentingComplaintLowerCategory = 'F402 - Specific (isolated) phobias' OR [SecondaryPresentingComplaint] = 'F402 - Specific (isolated) phobias') THEN 'F402 care- Specific Phobias'
		WHEN (r.PresentingComplaintHigherCategory = 'Anxiety and stress related disorders (Total)' OR r.[PrimaryPresentingComplaint] = 'Anxiety and stress related disorders (Total)') AND (r.PresentingComplaintLowerCategory = 'F410 - Panic disorder [episodic paroxysmal anxiety' OR [SecondaryPresentingComplaint] = 'F410 - Panic disorder [episodic paroxysmal anxiety') THEN 'F410 - Panic Disorder'
		WHEN (r.PresentingComplaintHigherCategory = 'Anxiety and stress related disorders (Total)' OR r.[PrimaryPresentingComplaint] = 'Anxiety and stress related disorders (Total)') AND (r.PresentingComplaintLowerCategory = 'F411 - Generalised Anxiety Disorder' OR [SecondaryPresentingComplaint] = 'F411 - Generalised Anxiety Disorder') THEN 'F411 - Generalised Anxiety'
		WHEN (r.PresentingComplaintHigherCategory = 'Anxiety and stress related disorders (Total)' OR r.[PrimaryPresentingComplaint] = 'Anxiety and stress related disorders (Total)') AND (r.PresentingComplaintLowerCategory = 'F412 - Mixed anxiety and depressive disorder' OR [SecondaryPresentingComplaint] = 'F412 - Mixed anxiety and depressive disorder') THEN 'F412 - Mixed Anxiety'
		WHEN (r.PresentingComplaintHigherCategory = 'Anxiety and stress related disorders (Total)' OR r.[PrimaryPresentingComplaint] = 'Anxiety and stress related disorders (Total)') AND (r.PresentingComplaintLowerCategory = 'F42 - Obsessive-compulsive disorder' OR [SecondaryPresentingComplaint] = 'F42 - Obsessive-compulsive disorder') THEN 'F42 - Obsessive Compulsive'
		WHEN (r.PresentingComplaintHigherCategory = 'Anxiety and stress related disorders (Total)' OR r.[PrimaryPresentingComplaint] = 'Anxiety and stress related disorders (Total)') AND (r.PresentingComplaintLowerCategory = 'F431 - Post-traumatic stress disorder' OR [SecondaryPresentingComplaint] = 'F431 - Post-traumatic stress disorder') THEN 'F431 - Post-traumatic Stress'
		WHEN (r.PresentingComplaintHigherCategory = 'Anxiety and stress related disorders (Total)' OR r.[PrimaryPresentingComplaint] = 'Anxiety and stress related disorders (Total)') AND (r.PresentingComplaintLowerCategory = 'F452 Hypochondriacal Disorders' OR [SecondaryPresentingComplaint] = 'F452 Hypochondriacal Disorders') THEN 'F452 - Hypochondrial disorder'
		WHEN (r.PresentingComplaintHigherCategory = 'Anxiety and stress related disorders (Total)' OR r.[PrimaryPresentingComplaint] = 'Anxiety and stress related disorders (Total)') AND (r.PresentingComplaintLowerCategory = 'Other F40-F43 code' OR [SecondaryPresentingComplaint] = 'Other F40-F43 code') THEN 'Other F40 to 43 - Other Anxiety'
		WHEN (r.PresentingComplaintHigherCategory = 'Anxiety and stress related disorders (Total)' OR r.[PrimaryPresentingComplaint] = 'Anxiety and stress related disorders (Total)') AND (r.PresentingComplaintLowerCategory IS NULL OR [SecondaryPresentingComplaint] IS NULL) THEN 'No Code' 
		ELSE 'Other' 
	END AS 'ProblemDescriptor'
    
    --Geography
    ,ch.Organisation_Code as 'Sub-ICBCode'
	,ch.Organisation_Name as 'Sub-ICBName'
	,ch.STP_Code as 'ICBCode'
	,ch.STP_Name as 'ICBName'
	,ch.Region_Name as 'RegionNameComm'
	,ch.Region_Code as 'RegionCodeComm'
	,ph.Organisation_Code as 'ProviderCode'
	,ph.Organisation_Name as 'ProviderName'
	,ph.Region_Name as 'RegionNameProv'
	--,ph.Region_Code as 'RegionCodeProv'
INTO [MHDInternal].[TEMP_TTAD_IET_Base]
FROM [MESH_IAPT].[IDS101referral] r
    INNER JOIN [mesh_IAPT].[IsLatest_SubmissionID] l ON r.[UniqueSubmissionID] = l.[UniqueSubmissionID] AND r.[AuditId] = l.[AuditId]
    LEFT JOIN [MHDInternal].[REFERENCE_CCG_2020_Lookup] c ON r.OrgIDComm = c.IC_CCG					
	LEFT JOIN [Reporting].[Ref_ODS_Commissioner_Hierarchies_ICB] ch ON c.CCG21 = ch.Organisation_Code AND ch.Effective_To IS NULL
	LEFT JOIN [Reporting].[Ref_ODS_Provider_Hierarchies_ICB] ph ON r.OrgID_Provider = ph.Organisation_Code AND ph.Effective_To IS NULL
	--Three tables for getting the up-to-date Sub-ICB/ICB/Region/Provider names/codes
    LEFT JOIN [MHDInternal].[TEMP_TTAD_IET_TypeAndDuration] i ON i.PathwayID = r.PathwayID


WHERE r.UsePathway_Flag = 'True' 
		AND l.IsLatest = 1	--To get the latest data
		AND r.CompletedTreatment_Flag = 'True'	--Data is filtered to only look at those who have completed a course of treatment
		AND r.ServDischDate BETWEEN l.ReportingPeriodStartDate AND l.ReportingPeriodEndDate	
		AND l.[ReportingPeriodStartDate] BETWEEN DATEADD(MONTH, @Offset, @PeriodStart) AND @PeriodStart	--for refresh, the offset should be 0 as only want the data for the latest month
		
		
IF OBJECT_ID ('[MHDInternal].[DASHBOARD_TTAD_IET_Aggregated]') IS NOT NULL DROP TABLE [MHDInternal].[DASHBOARD_TTAD_IET_Aggregated]
--National, IET
SELECT 
Month
,CAST('National' AS VARCHAR(50)) AS OrgType
,CAST('All Regions' AS VARCHAR(255)) AS Region
,CAST('England' AS VARCHAR(255)) AS OrgName
,CAST('ENG' AS VARCHAR(50)) AS OrgCode
,CAST('IET' AS VARCHAR(50)) AS AppointmentType
,InternetEnabledTherapy_Count
,IntEnabledTherProg
,DurationIntEnabledTher
,IntegratedSoftwareInd
,EndCode
,EndCodeDescription
,ProblemDescriptor
,SUM(CompTreatFlagRecFlag) AS CompTreatFlagRecFlag
,SUM(CompTreatFlagNotCasenessFlag) AS CompTreatFlagNotCasenessFlag
,SUM(CompTreatFlagRelImpFlag) AS CompTreatFlagRelImpFlag
,SUM(CompTreatFlagRelRecFlags) AS CompTreatFlagRelRecFlags
,SUM(CompTreatFlag) AS CompTreatFlag
INTO [MHDInternal].[DASHBOARD_TTAD_IET_Aggregated]
FROM [MHDInternal].[TEMP_TTAD_IET_Base]
WHERE InternetEnabledTherapy_Count>=1
GROUP BY 
	Month
	,InternetEnabledTherapy_Count
	,IntEnabledTherProg
	,DurationIntEnabledTher
	,IntegratedSoftwareInd
	,EndCode
	,EndCodeDescription
	,ProblemDescriptor

--National, No IET
INSERT INTO [MHDInternal].[DASHBOARD_TTAD_IET_Aggregated]
SELECT 
Month
,CAST('National' AS VARCHAR(50)) AS OrgType
,CAST('All Regions' AS VARCHAR(255)) AS Region
,CAST('England' AS VARCHAR(255)) AS OrgName
,CAST('ENG' AS VARCHAR(50)) AS OrgCode
,'No IET' AS AppointmentType
,InternetEnabledTherapy_Count
,IntEnabledTherProg
,DurationIntEnabledTher
,IntegratedSoftwareInd
,EndCode
,EndCodeDescription
,ProblemDescriptor
,SUM(CompTreatFlagRecFlag) AS CompTreatFlagRecFlag
,SUM(CompTreatFlagNotCasenessFlag) AS CompTreatFlagNotCasenessFlag
,SUM(CompTreatFlagRelImpFlag) AS CompTreatFlagRelImpFlag
,SUM(CompTreatFlagRelRecFlags) AS CompTreatFlagRelRecFlags
,SUM(CompTreatFlag) AS CompTreatFlag
FROM [MHDInternal].[TEMP_TTAD_IET_Base]
WHERE InternetEnabledTherapy_Count=0
GROUP BY 
	Month
	,IntEnabledTherProg
	,InternetEnabledTherapy_Count
	,DurationIntEnabledTher
	,IntegratedSoftwareInd
	,EndCode
	,EndCodeDescription
	,ProblemDescriptor

--Region, IET
INSERT INTO [MHDInternal].[DASHBOARD_TTAD_IET_Aggregated]
SELECT 
Month
,'Region' AS OrgType
,RegionNameComm AS Region
,RegionNameComm AS OrgName
,RegionCodeComm AS OrgCode
,'IET' AS AppointmentType
,InternetEnabledTherapy_Count
,IntEnabledTherProg
,DurationIntEnabledTher
,IntegratedSoftwareInd
,EndCode
,EndCodeDescription
,ProblemDescriptor
,SUM(CompTreatFlagRecFlag) AS CompTreatFlagRecFlag
,SUM(CompTreatFlagNotCasenessFlag) AS CompTreatFlagNotCasenessFlag
,SUM(CompTreatFlagRelImpFlag) AS CompTreatFlagRelImpFlag
,SUM(CompTreatFlagRelRecFlags) AS CompTreatFlagRelRecFlags
,SUM(CompTreatFlag) AS CompTreatFlag
FROM [MHDInternal].[TEMP_TTAD_IET_Base]
WHERE InternetEnabledTherapy_Count>=1
GROUP BY 
	Month
	,RegionNameComm
	,RegionCodeComm
	,InternetEnabledTherapy_Count
	,IntEnabledTherProg
	,DurationIntEnabledTher
	,IntegratedSoftwareInd
	,EndCode
	,EndCodeDescription
	,ProblemDescriptor

--Region, No IET
INSERT INTO [MHDInternal].[DASHBOARD_TTAD_IET_Aggregated]
SELECT 
Month
,'Region' AS OrgType
,RegionNameComm AS Region
,RegionNameComm  AS OrgName
,RegionCodeComm  AS OrgCode
,'No IET' AS AppointmentType
,InternetEnabledTherapy_Count
,IntEnabledTherProg
,DurationIntEnabledTher
,IntegratedSoftwareInd
,EndCode
,EndCodeDescription
,ProblemDescriptor
,SUM(CompTreatFlagRecFlag) AS CompTreatFlagRecFlag
,SUM(CompTreatFlagNotCasenessFlag) AS CompTreatFlagNotCasenessFlag
,SUM(CompTreatFlagRelImpFlag) AS CompTreatFlagRelImpFlag
,SUM(CompTreatFlagRelRecFlags) AS CompTreatFlagRelRecFlags
,SUM(CompTreatFlag) AS CompTreatFlag
FROM [MHDInternal].[TEMP_TTAD_IET_Base]
WHERE InternetEnabledTherapy_Count=0
GROUP BY 
	Month
	,RegionNameComm
	,RegionCodeComm 
	,InternetEnabledTherapy_Count
	,IntEnabledTherProg
	,DurationIntEnabledTher
	,IntegratedSoftwareInd
	,EndCode
	,EndCodeDescription
	,ProblemDescriptor

--ICB, IET
INSERT INTO [MHDInternal].[DASHBOARD_TTAD_IET_Aggregated]
SELECT 
Month
,'ICB' AS OrgType
,RegionNameComm AS Region
,[ICBName] AS OrgName
,[ICBCode] AS OrgCode
,'IET' AS AppointmentType
,InternetEnabledTherapy_Count
,IntEnabledTherProg
,DurationIntEnabledTher
,IntegratedSoftwareInd
,EndCode
,EndCodeDescription
,ProblemDescriptor
,SUM(CompTreatFlagRecFlag) AS CompTreatFlagRecFlag
,SUM(CompTreatFlagNotCasenessFlag) AS CompTreatFlagNotCasenessFlag
,SUM(CompTreatFlagRelImpFlag) AS CompTreatFlagRelImpFlag
,SUM(CompTreatFlagRelRecFlags) AS CompTreatFlagRelRecFlags
,SUM(CompTreatFlag) AS CompTreatFlag
FROM [MHDInternal].[TEMP_TTAD_IET_Base]
WHERE InternetEnabledTherapy_Count>=1
GROUP BY 
	Month
	,RegionNameComm
	,[ICBName]
	,[ICBCode]
	,InternetEnabledTherapy_Count
	,IntEnabledTherProg
	,DurationIntEnabledTher
	,IntegratedSoftwareInd
	,EndCode
	,EndCodeDescription
	,ProblemDescriptor

--ICB, No IET
INSERT INTO [MHDInternal].[DASHBOARD_TTAD_IET_Aggregated]
SELECT 
Month
,'ICB' AS OrgType
,RegionNameComm AS Region
,[ICBName] AS OrgName
,[ICBCode] AS OrgCode
,'No IET' AS AppointmentType
,InternetEnabledTherapy_Count
,IntEnabledTherProg
,DurationIntEnabledTher
,IntegratedSoftwareInd
,EndCode
,EndCodeDescription
,ProblemDescriptor
,SUM(CompTreatFlagRecFlag) AS CompTreatFlagRecFlag
,SUM(CompTreatFlagNotCasenessFlag) AS CompTreatFlagNotCasenessFlag
,SUM(CompTreatFlagRelImpFlag) AS CompTreatFlagRelImpFlag
,SUM(CompTreatFlagRelRecFlags) AS CompTreatFlagRelRecFlags
,SUM(CompTreatFlag) AS CompTreatFlag
FROM [MHDInternal].[TEMP_TTAD_IET_Base]
WHERE InternetEnabledTherapy_Count=0
GROUP BY 
	Month
	,RegionNameComm
	,[ICBName]
	,[ICBCode]
	,InternetEnabledTherapy_Count
	,IntEnabledTherProg
	,DurationIntEnabledTher
	,IntegratedSoftwareInd
	,EndCode
	,EndCodeDescription
	,ProblemDescriptor

--Sub-ICB, IET
INSERT INTO [MHDInternal].[DASHBOARD_TTAD_IET_Aggregated]
SELECT 
Month
,'Sub-ICB' AS OrgType
,RegionNameComm AS Region
,[Sub-ICBName] AS OrgName
,[Sub-ICBCode] AS OrgCode
,'IET' AS AppointmentType
,InternetEnabledTherapy_Count
,IntEnabledTherProg
,DurationIntEnabledTher
,IntegratedSoftwareInd
,EndCode
,EndCodeDescription
,ProblemDescriptor
,SUM(CompTreatFlagRecFlag) AS CompTreatFlagRecFlag
,SUM(CompTreatFlagNotCasenessFlag) AS CompTreatFlagNotCasenessFlag
,SUM(CompTreatFlagRelImpFlag) AS CompTreatFlagRelImpFlag
,SUM(CompTreatFlagRelRecFlags) AS CompTreatFlagRelRecFlags
,SUM(CompTreatFlag) AS CompTreatFlag
FROM [MHDInternal].[TEMP_TTAD_IET_Base]
WHERE InternetEnabledTherapy_Count>=1
GROUP BY 
	Month
	,RegionNameComm
	,[Sub-ICBName]
	,[Sub-ICBCode]
	,InternetEnabledTherapy_Count
	,IntEnabledTherProg
	,DurationIntEnabledTher
	,IntegratedSoftwareInd
	,EndCode
	,EndCodeDescription
	,ProblemDescriptor

--Sub-ICB, No IET
INSERT INTO [MHDInternal].[DASHBOARD_TTAD_IET_Aggregated]
SELECT 
Month
,'Sub-ICB' AS OrgType
,RegionNameComm AS Region
,[Sub-ICBName] AS OrgName
,[Sub-ICBCode] AS OrgCode
,'No IET' AS AppointmentType
,InternetEnabledTherapy_Count
,IntEnabledTherProg
,DurationIntEnabledTher
,IntegratedSoftwareInd
,EndCode
,EndCodeDescription
,ProblemDescriptor
,SUM(CompTreatFlagRecFlag) AS CompTreatFlagRecFlag
,SUM(CompTreatFlagNotCasenessFlag) AS CompTreatFlagNotCasenessFlag
,SUM(CompTreatFlagRelImpFlag) AS CompTreatFlagRelImpFlag
,SUM(CompTreatFlagRelRecFlags) AS CompTreatFlagRelRecFlags
,SUM(CompTreatFlag) AS CompTreatFlag
FROM [MHDInternal].[TEMP_TTAD_IET_Base]
WHERE InternetEnabledTherapy_Count=0
GROUP BY 
	Month
	,RegionNameComm
	,[Sub-ICBName]
	,[Sub-ICBCode]
	,InternetEnabledTherapy_Count
	,IntEnabledTherProg
	,DurationIntEnabledTher
	,IntegratedSoftwareInd
	,EndCode
	,EndCodeDescription
	,ProblemDescriptor

--Provider, IET
INSERT INTO [MHDInternal].[DASHBOARD_TTAD_IET_Aggregated]
SELECT 
Month
,'Provider' AS OrgType
,RegionNameProv AS Region
,[ProviderName] AS OrgName
,[ProviderCode] AS OrgCode
,'IET' AS AppointmentType
,InternetEnabledTherapy_Count
,IntEnabledTherProg
,DurationIntEnabledTher
,IntegratedSoftwareInd
,EndCode
,EndCodeDescription
,ProblemDescriptor
,SUM(CompTreatFlagRecFlag) AS CompTreatFlagRecFlag
,SUM(CompTreatFlagNotCasenessFlag) AS CompTreatFlagNotCasenessFlag
,SUM(CompTreatFlagRelImpFlag) AS CompTreatFlagRelImpFlag
,SUM(CompTreatFlagRelRecFlags) AS CompTreatFlagRelRecFlags
,SUM(CompTreatFlag) AS CompTreatFlag
FROM [MHDInternal].[TEMP_TTAD_IET_Base]
WHERE InternetEnabledTherapy_Count>=1
GROUP BY 
	Month
	,RegionNameProv
	,[ProviderName]
	,[ProviderCode]
	,InternetEnabledTherapy_Count
	,IntEnabledTherProg
	,DurationIntEnabledTher
	,IntegratedSoftwareInd
	,EndCode
	,EndCodeDescription
	,ProblemDescriptor

--Provider, No IET
INSERT INTO [MHDInternal].[DASHBOARD_TTAD_IET_Aggregated]
SELECT 
Month
,'Provider' AS OrgType
,RegionNameProv AS Region
,[ProviderName] AS OrgName
,[ProviderCode] AS OrgCode
,'No IET' AS AppointmentType
,InternetEnabledTherapy_Count
,IntEnabledTherProg
,DurationIntEnabledTher
,IntegratedSoftwareInd
,EndCode
,EndCodeDescription
,ProblemDescriptor
,SUM(CompTreatFlagRecFlag) AS CompTreatFlagRecFlag
,SUM(CompTreatFlagNotCasenessFlag) AS CompTreatFlagNotCasenessFlag
,SUM(CompTreatFlagRelImpFlag) AS CompTreatFlagRelImpFlag
,SUM(CompTreatFlagRelRecFlags) AS CompTreatFlagRelRecFlags
,SUM(CompTreatFlag) AS CompTreatFlag
FROM [MHDInternal].[TEMP_TTAD_IET_Base]
WHERE InternetEnabledTherapy_Count=0
GROUP BY 
	Month
	,RegionNameProv
	,[ProviderName]
	,[ProviderCode]
	,InternetEnabledTherapy_Count
	,IntEnabledTherProg
	,DurationIntEnabledTher
	,IntegratedSoftwareInd
	,EndCode
	,EndCodeDescription
	,ProblemDescriptor

