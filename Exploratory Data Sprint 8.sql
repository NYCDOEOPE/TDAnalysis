--Count number of distinct AP Courses offered per school in 2018
-- Counts for current term only to reduce duplicates
-- Excludes Lab courses
--------------------------------------------------------------------------------------------------------------------------------------	
-- Set the general working environment/programmability:
--------------------------------------------------------------------------------------------------------------------------------------
	DECLARE @RunDate DATETIME
		SET @RunDate = DATEADD(DAY, DATEDIFF(DAY, 0, CURRENT_TIMESTAMP), 0)
	DECLARE @SY INT; -- School Year used for STARS (e.g. '2015' for the 2015-16 SY)
	DECLARE @SY_StartDate DATETIME;
	DECLARE @SY_EndDate DATETIME;
	DECLARE @TodayDate DATETIME;
	DECLARE @T1 DATETIME;
	DECLARE @T2 DATETIME;
		SET @TodayDate = DATEADD(DAY, DATEDIFF(DAY, 0, CURRENT_TIMESTAMP), 0);

	IF DATEPART(MONTH,@RunDate) < 7 -- Jan-June should represent the prior calendar year
		SET @SY = CAST(DATEPART(YEAR,@RunDate)-1 AS VARCHAR);
	ELSE -- Jul-Dec indicates the current year in STARS
	BEGIN
		IF DATEPART(MONTH,@RunDate) > 7 OR (DATEPART(MONTH,@RunDate) = 7 AND DATEPART(DAY,@RunDate) > 24)
			SET @SY = CAST(DATEPART(YEAR,@RunDate) AS VARCHAR)
	END

		SET @SY_StartDate = (SELECT MIN([BeginDate]) FROM [STARS_INT].[dbo].[SchoolTerm] WHERE [SchoolYear] = @SY AND [TermId] <> 7 GROUP BY [SchoolYear])
		SET @SY_EndDate = (SELECT MAX([EndDate]) FROM [STARS_INT].[dbo].[SchoolTerm] WHERE [SchoolYear] = @SY AND [TermId] <> 7 GROUP BY [SchoolYear])

IF OBJECT_ID('tempdb..#CurrentTerm') IS NOT NULL DROP TABLE #CurrentTerm
	SELECT
		[NumericSchoolDBN]
		,[SchoolYear]
		,[TermId]
		,1 AS 'IsCurrent'
	INTO #CurrentTerm
	FROM
		[STARS_INT].[dbo].[SchoolTerm] [st] (NOLOCK)
	WHERE
		[BeginDate] <= @RunDate
		AND [EndDate] >= @RunDate
		AND [SchoolYear] = @SY	

IF OBJECT_ID('tempdb..#TermModel') IS NOT NULL DROP TABLE #TermModel
	select s.schooldbn, s.numericschooldbn, max(t.termid) as [TermModel]
	into #TermModel
	from stars_int.dbo.SchoolTerm T
		Inner join stars_int.dbo.school S
			on t.NumericSchoolDBN=s.NumericSchoolDBN
	where t.schoolyear=OADM_INT.dbo.DM_GET_SCHOOL_YEAR_F(GETDATE())-1 /*For School Year*/
	group by s.SchoolDBN, s.NumericSchoolDBN

IF OBJECT_ID('tempdb..#term') IS NOT NULL DROP TABLE #Term
	select 
		ct.NumericSchoolDBN
		,tm.schooldbn
		,ct.schoolyear
		,tm.[TermModel]
		,ct.termid
		,ct.iscurrent
	into #term
	from #currentterm CT
	inner join #termmodel TM
	on ct.NumericSchoolDBN=tm.NumericSchoolDBN

IF OBJECT_ID('tempdb..#biog') IS NOT NULL DROP TABLE #biog
	select distinct student_id,
		school_dbn,
		ethnic_cde,
		status,
		grade_level
	into #biog
	from atslink.ats_demo.dbo.biogdata 
	where status='a'

IF OBJECT_ID('tempdb..#totalenroll') IS NOT NULL DROP TABLE #totalenroll
	select distinct
		count(student_id) as enrollment,
		school_dbn
	into #totalenroll
	from #biog
	group by school_dbn

IF OBJECT_ID('tempdb..#base') IS NOT NULL DROP TABLE #base
	select y.schooldbn,
		y.APCourseCount,
		count(biog.student_id) as StudentCount
	into #base
	from(
		select
			x.schooldbn
			,count (x.Coursecode) as APCourseCount
		from (
			select distinct 
				sch.schooldbn,
				cs.termid,
				cs.coursecode,
				course.CourseName

			from dmr_int.rqp.CSSEnrollment css
				inner join dmr_int.rqp.CourseSection cs 
					on css.coursesectionid=cs.coursesectionid
				inner join stars_int.dbo.school sch
					on cs.numericschooldbn = sch.numericschooldbn
				left join dmr_int.rqp.cstenrollment cst
					on cst.CourseSectionID = css.CourseSectionID
				left join stars_int.dbo.Personnel per
					on per.PersonnelID = cst.PersonnelID
				left join stars_int.dbo.course course
					on course.NumericSchoolDBN=sch.NumericSchoolDBN
					and course.coursecode=cs.CourseCode
					and course.TermId=cs.TermID
					and course.schoolyear=cs.schoolyear
				left join #term 
					on #term.NumericSchoolDBN=sch.NumericSchoolDBN

			where cs.schoolyear = 2018
			--and sch.schooldbn='01m292'
			and substring(cs.CourseCode,6,1)='x'
			and substring(cs.coursecode,1,1)<>'z'
			and substring(cs.coursecode,7,1)<>'l'
			and #term.TermId=cs.TermID

			) x
			group by x.SchoolDBN
		) y

	left join #biog biog
	on school_dbn=y.schooldbn
	where biog.status='a'
	group by y.schooldbn, y.APCourseCount

----~~~~~~~~~~~~~~~~~~~~~~~~~~
IF OBJECT_ID('tempdb..#apbase') IS NOT NULL DROP TABLE #apbase

select distinct 
		css.studentid, 
		sch.schooldbn,
		cs.schoolyear
	into #APbase
	from dmr_int.rqp.CSSEnrollment css
		inner join dmr_int.rqp.CourseSection cs 
			on css.coursesectionid=cs.coursesectionid
		inner join stars_int.dbo.school sch
			on cs.numericschooldbn = sch.numericschooldbn
		left join dmr_int.rqp.cstenrollment cst
			on cst.CourseSectionID = css.CourseSectionID
		left join #term
			on #term.NumericSchoolDBN=sch.NumericSchoolDBN
		inner join #biog biog 
		on biog.school_dbn=sch.schooldbn
		and biog.student_id=css.studentid
	where cs.schoolyear = 2018
		and substring(cs.CourseCode,6,1)='x'
		and substring(cs.coursecode,1,1)<>'z'
		and substring(cs.coursecode,7,1)<>'l'
		and #term.TermId=cs.TermID

IF OBJECT_ID('tempdb..#APEnroll') IS NOT NULL DROP TABLE #APEnroll

select distinct
schooldbn,
count(x.studentid) as APEnroll
into #apenroll
from #APbase x
group by x.SchoolDBN

IF OBJECT_ID('tempdb..#Counts') IS NOT NULL DROP TABLE #Counts
	select
		a.schooldbn
		,a.APCourseCount
		,b.APEnroll
		,a.studentcount
	into #counts
	from #base a 
		left join #apenroll b
		on a.schooldbn=b.SchoolDBN

------------------------------------
--Add in # of students per ethnicity
------------------------------------
IF OBJECT_ID('tempdb..#races') IS NOT NULL DROP TABLE #races
	select distinct 
		school_dbn,
		student_id,
		case when ethnic_cde='1' then 1 when ethnic_cde='B' then 1 else 0 end as 'American Indian or Alaskan Native',
		case when ethnic_cde='2' then 1 when ethnic_cde='C' then 1 else 0 end as 'Asian or Pacific Islander',
		case WHEN ethnic_cde='3' then 1 when ethnic_cde='A' then 1 else 0 end as 'Hispanic',
		case when ethnic_cde='4' then 1 when ethnic_cde='E' then 1 else 0 end as 'Black',
		case when ethnic_cde='5' then 1 when ethnic_cde='F' then 1 else 0 end as 'White',
		case when ethnic_cde='6' then 1 when ethnic_cde is null then 1 else 0 end as 'Refused to sign',
		case when ethnic_cde='7' then 1 when ethnic_cde='G' then 1 else 0 end as 'Multi-Racial',
		case when ethnic_cde='D' then 1 else 0 end as 'Native Hawaiian or other Pacific Islander'	
	into #races
	from #biog
		where status='a'
		--and school_dbn in (select schooldbn from #counts) --Comment out for every school
		
		
IF OBJECT_ID('tempdb..#racecount') IS NOT NULL DROP TABLE #racecount
	select
		school_dbn
		,sum([American Indian or Alaskan Native]) as 'AmIn'
		,sum([Asian or Pacific Islander]) as 'Asian'
		,sum([Hispanic]) as 'Hispanic'
		,sum([Black]) as 'Black'
		,sum([White]) as 'White'
		,sum([Refused to sign]) as 'Unknown/Refused to Sign'
		,sum([Multi-Racial]) as 'Multi-Racial'
		,sum([Native Hawaiian or other Pacific Islander]) as 'Native Hawaiian or Other PI'
	into #racecount
	from #races
	where student_id in (select studentid from #APbase)		-- Comment out if you want all students, keep in if you want just students in AP for each race
	group by school_dbn

-- Change where condition depending on if you want all students or just students in AP for each grade level
IF OBJECT_ID('tempdb..#table') IS NOT NULL DROP TABLE #table
	select school_dbn, grade_level, count(student_id) as CNT 
	into #table
	from #biog
	where status='a' 
	and student_id in (select studentid from #APbase)		-- Comment out if you want all students, keep in if you want just students in AP for each grade level
	group by grade_level, school_dbn order by school_dbn

	

IF OBJECT_ID('tempdb..#gradetable') IS NOT NULL DROP TABLE #gradetable
select school_dbn,
	sum([PK]) as [PK],
	sum([0K]) as [0K],
	sum([01]) as [01],
	sum([02]) as [02],
	sum([03]) as [03],
	sum([04]) as [04],
	sum([05]) as [05],
	sum([06]) as [06],
	sum([07]) as [07],
	sum([08]) as [08],
	sum([09]) as [09],
	sum([10]) as [10],
	sum([11]) as [11],
	sum([12]) as [12]
into #gradetable
from
	(
		select school_dbn,
		case when grade_level='PK' then CNT else 0 end as 'PK',
		case when grade_level='0K' then CNT else 0 end as '0K',
		case when grade_level='01' then CNT else 0 end as '01',
		case when grade_level='02' then CNT else 0 end as '02',
		case when grade_level='03' then CNT else 0 end as '03',
		case when grade_level='04' then CNT else 0 end as '04',
		case when grade_level='05' then CNT else 0 end as '05',
		case when grade_level='06' then CNT else 0 end as '06',
		case when grade_level='07' then CNT else 0 end as '07',
		case when grade_level='08' then CNT else 0 end as '08',
		case when grade_level='09' then CNT else 0 end as '09',
		case when grade_level='10' then CNT else 0 end as '10',
		case when grade_level='11' then CNT else 0 end as '11',
		case when grade_level='12' then CNT else 0 end as '12'
		from #table
	) x
group by x.school_dbn

/* Select schools with AP courses only
select a.*
	,b.Black
	,b.White
	,b.Asian
	,b.hispanic
	,b.AmIn
	,b.[Native Hawaiian or Other PI]
	,b.[Multi-Racial]
	,b.[Unknown/Refused to Sign]
	,c.[PK]
	,c.[0K]
	,c.[01]
	,c.[02]
	,c.[03]
	,c.[04]
	,c.[05]
	,c.[06]
	,c.[07]
	,c.[08]
	,c.[09]
	,c.[10]
	,c.[11]
	,c.[12]
from #counts a
left join #racecount b
on a.SchoolDBN=b.school_dbn
left join #gradetable c
on a.schooldbn=c.school_dbn
order by schooldbn
*/

select
	a.school_dbn
	,d.enrollment
	,case when (b.[09]+b.[10]+b.[11]+b.[12]=0) then 'Non-HS' else 'HS' end as 'SchoolType'
	,isnull(c.APCourseCount,0) as APCourses
	,isnull(c.apenroll,0) as APEnrollment
	,a.Black
	,a.White
	,a.Asian
	,a.hispanic
	,a.AmIn
	,a.[Native Hawaiian or Other PI]
	,a.[Multi-Racial]
	,a.[Unknown/Refused to Sign]
	,b.[PK]
	,b.[0K]
	,b.[01]
	,b.[02]
	,b.[03]
	,b.[04]
	,b.[05]
	,b.[06]
	,b.[07]
	,b.[08]
	,b.[09]
	,b.[10]
	,b.[11]
	,b.[12]
from #racecount a 
left join #gradetable b
on a.school_dbn=b.school_dbn
left join #counts c
on c.schooldbn=a.school_dbn
left join #totalenroll d
on d.school_dbn = a.school_dbn
where SUBSTRING(a.School_DBN,1,2) NOT IN ('84','88') /* Exclude Districts 84 & 88 */ 
       AND a.School_DBN NOT LIKE '%Z%'  /* Excluding Test Schools */ 
       AND a.School_DBN NOT LIKE '%444'  /* Excluding Home Schools */
       AND a.School_DBN <> '02M972'  /* Excluding Office of Academic Policy School*/

--select distinct * from #apenroll where schooldbn='01m448'
--select distinct * from #counts where schooldbn='01m448'
--select distinct * from #apbase where schooldbn='01m448'
--select distinct * from #races where school_dbn='01m448' and student_id in (select studentid from #apbase)

--select student_id, status, school_dbn from atslink.ats_demo.dbo.biogdata where student_id = 242145134
