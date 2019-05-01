clear all
graph drop _all
clear matrix
cd "\\CENTRAL.NYCED.ORG\DoE$\Assessment & Accountability\RPSG\ACADEMIC POLICY\Research & Analytics\Michael Ho\ToolsDot"
set autotabgraphs on
import excel "TD Data HS Only.xlsx", sheet("HS Only") firstrow

rename Q GRADE1
rename R GRADE2
rename S GRADE3
rename T GRADE4
rename U GRADE5
rename V GRADE6
rename W GRADE7
rename X GRADE8
rename Y GRADE9
rename Z GRADE10
rename AA GRADE11
rename AB GRADE12

*--------------------------------------------------------------------------------------
* List and check values of the variables in the dataset, for the first 10 cases
*--------------------------------------------------------------------------------------

list in 1/10, clean

*--------------------------------------------------------------------------------------
* View basic summary statistics for your variables.  ", separator(`c(k)')" is purely
* stylistic and optional
*--------------------------------------------------------------------------------------
su, sep(`c(k)')

*--------------------------------------------------------------------------------------
* Discrete histogram of the outcome variables
*--------------------------------------------------------------------------------------
hist APEnrollment, discrete freq name(APEnroll, replace)
hist APCourses, discrete freq name(APCourses, replace)

*--------------------------------------------------------------------------------------
* Univariate distributions of possible predictors
*--------------------------------------------------------------------------------------
ssc inst catplot 
catplot SizeNYSPHSAA, name(Sizecount, replace)
//hist enrollment, discrete freq name(Enrollment, replace)

*--------------------------------------------------------------------------------------
* Bivariate distributions: Outcome and Categorical Question Predictor
* What size are the schools that offer more ap/advanced courses, and how many high schools in NYC are small schools?
*--------------------------------------------------------------------------------------
tab SizeNYSPHSAA, summarize(APCourses)
graph hbox APCourses, over(SizeNYSPHSAA) name(Graph1, replace) title("AP Courses by NYSPHSAA School Size")
twoway (scatter APCourses enrollment) (lfit APCourses enrollment) if enrollment<=3500, ///
xlab(0(500)3500) ytitle("AP Courses") xtitle("School Enrollment") title("AP Courses by School Enrollment") name(All, replace)

/*
twoway (scatter APCourses Black) (lfit APCourses Black)if enrollment<=3500, ///
xlab(0(500)1300) ytitle("AP Courses") xtitle("Black Student Enrollment") title("AP Courses by School Enrollment") name(Black, replace)
twoway (scatter APCourses White) (lfit APCourses White), name(White, replace)
twoway (scatter APCourses Asian) (lfit APCourses Asian), name(Asian, replace)
twoway (scatter APCourses hispanic) (lfit APCourses hispanic), name(Hispanic, replace)*/

*--------------------------------------------------------------------------------------
* What % of students in each school takes ap courses, and what are their demographics?
* EXCEL: For each race, what % attends small schools to very large schools? (See td data all)
*--------------------------------------------------------------------------------------




