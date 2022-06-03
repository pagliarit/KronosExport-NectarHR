--Query written by Tim Pagliari
--pagliari.timothy@cuyahogabdd.org
--last edit 6/1/2022
--Nectar Export file for SFTP flat file ingestion
--Runs nightly in SSIS on Derby, discrepency export saves on \\Edam\group\reports\HR\
--
--

SELECT distinct 
--   , ei.EmployeeSSN as SSN 
      rtrim(vp.FirstName) as first_name
     , rtrim(vp.LastName) as last_name
     , RTRIM(SHORTNM) as preferred_name
     , REPLACE(CONVERT(varchar(11), originalhiredate, 106),' ','-') as hire_date
     , rtrim(isnull(rtrim(vem.EMailAddress),'')) as email
     , REPLACE(CONVERT(varchar(6),  vp.BirthDate, 106),' ','-') as birth_Date
     ,Manemail.supemail manager_email
	 ,rtrim(esi.EmpNo) as employee_id
--     ,esi.EffectiveDate

FROM [tkcsdb].[dbo].[vHRL_Employeeinfo] ei
     left join (
          SELECT PersonIdNo, PersonTaxIdNo, LastName, FirstName, MiddleName, BirthDate, MAX(PersonToEffectDate) 'EffectiveDate' FROM vPersons
             where PersonToEffectDate = '3000-01-01'
--             where PersonToEffectDate <= @From_Timeframe
          GROUP BY PersonIdNo, PersonTaxIdNo, LastName, FirstName, MiddleName, BirthDate)  vp on ei.EmployeeSSN = vp.PersonTaxIdNo
     left JOIN vHRL_EmploymentStatusInfo  esi
          ON esi.EmployeeSSN = vp.PersonTaxIdNo
     left join VP_EMPLOYEEV42 ve
      on esi.EmpNo = ve.PERSONNUM
     left JOIN (
          SELECT EmployeeSSN, PositionCode, SalariedHourly, MAX(FromEffectiveDate) 'EffectiveDate' FROM dbo.vHRL_PositionInfo  
            where ToEffectiveDate = '3000-01-01'
 --              where ToEffectiveDate <= @From_Timeframe 
         GROUP BY EmployeeSSN, PositionCode, SalariedHourly) vpi ON vpi.EmployeeSSN = ei.EmployeeSSN
     left join (
            select Positioncode, PositionCodeDescription, OrganizationString  from KIC_HRL_PositionCodesInfo 
              where OrganizationString like 'Man%'
            group by positioncode, PositionCodeDescription, OrganizationString) vpci
               on vpi.PositionCode = vpci.PositionCode
     left JOIN vHRL_PayStatusInfo vps
            on vps.EmployeeSSN = ei.EmployeeSSN  
      LEFT OUTER JOIN VP_PERSONCUSTDATA vpc 
            ON ve.PERSONNUM = vpc.PERSONNUM
            and vpc.customdatadefid = 1
       left join vEMAIL vem on vp.PersonIdNo = vem.PersonIdNo
                                  and vem.EmailPrimaryInd = 1  
		
		
		
		left outer join (select esi2.empno supnumber, vem2.EMailAddress supemail --generate dynamic manager email fields
		from [tkcsdb].[dbo].[vHRL_Employeeinfo] ei2
		left join (
          SELECT PersonIdNo, PersonTaxIdNo, LastName, FirstName, MiddleName, BirthDate, MAX(PersonToEffectDate) 'EffectiveDate' FROM vPersons
             where PersonToEffectDate = '3000-01-01' GROUP BY PersonIdNo, PersonTaxIdNo, LastName, FirstName, MiddleName, BirthDate)  vp2 on ei2.EmployeeSSN = vp2.PersonTaxIdNo
		left JOIN vHRL_EmploymentStatusInfo  esi2
          ON esi2.EmployeeSSN = vp2.PersonTaxIdNo
		left join vEMAIL vem2 on vp2.PersonIDNo = vem2.PersonIdNo ) ManEmail on SUPERVISORNUM = ManEmail.supnumber --left join (SELECT rtrim(esi.EmpNo) as xempid, SUPERVISORFULLNAME supname ,SUPERVISORNUM	supid) managers on managers.xempid = manager_ID

    where  vps.EffectiveDate = (select MAX(vps2.Effectivedate)
                                from vHRL_PayStatusInfo vps2
                               where vps.EmployeeSSN = vps2.EmployeeSSN
                               and vps2.EffectiveDate <= getdate())
    and esi.EffectiveDate = (select MAX(esi2.EffectiveDate)
                                from  vHRL_EmploymentStatusInfo  esi2
                               where esi.EmployeeSSN = esi2.EmployeeSSN
                               and esi2.EffectiveDate <= GETDATE())
    and esi.EmployeeStatus = 'active'
    order by last_name asc