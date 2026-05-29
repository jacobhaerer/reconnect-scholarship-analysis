preserve
collapse (mean) mean_enroll= Enrollment `W' (count) N=Enrollment, by(treated post)

label define Lgrp 0 "Control" 1 "Treated"
label values treated Lgrp
label define Lpp 0 "Pre" 1 "Post"
label values post Lpp

reshape wide mean_enroll N, i(treated) j(post)
rename (mean_enroll0 mean_enroll1 N0 N1) ///
       (pre_mean      post_mean    N_pre N_post)
gen change = post_mean - pre_mean

* ==== Pull numbers into locals ====
quietly su pre_mean  if Reconnect==1, meanonly
local Tpre  = r(mean)
quietly su post_mean if Reconnect==1, meanonly
local Tpost = r(mean)
quietly su change    if Reconnect==1, meanonly
local Tchg  = r(mean)
quietly su N_pre     if Reconnect==1, meanonly
local TNpre = r(mean)
quietly su N_post    if Reconnect==1, meanonly
local TNpost= r(mean)

quietly su pre_mean  if Reconnect==0, meanonly
local Cpre  = r(mean)
quietly su post_mean if Reconnect==0, meanonly
local Cpost = r(mean)
quietly su change    if Reconnect==0, meanonly
local Cchg  = r(mean)
quietly su N_pre     if Reconnect==0, meanonly
local CNpre = r(mean)
quietly su N_post    if Reconnect==0, meanonly
local CNpost= r(mean)

local DID = `Tchg' - `Cchg'

* ==== Nicely print to Results window ====
di as text "{hline 78}"
di as text %12s "Group" ///
   _col(20) "Pre mean" _col(34) "Post mean" _col(50) "Change" ///
   _col(62) "N_pre" _col(70) "N_post"
di as text "{hline 78}"
di as res  %12s "Treated"  ///
   _col(20) %9.3f `Tpre'  _col(34) %9.3f `Tpost'  _col(50) %9.3f `Tchg' ///
   _col(62) %6.0f `TNpre' _col(70) %6.0f `TNpost'
di as res  %12s "Control" ///
   _col(20) %9.3f `Cpre'  _col(34) %9.3f `Cpost'  _col(50) %9.3f `Cchg' ///
   _col(62) %6.0f `CNpre' _col(70) %6.0f `CNpost'
di as text "{hline 78}"
di as res  %12s "DiD (ΔT−ΔC)" _col(50) %9.3f `DID'
di as text "{hline 78}"

* ==== Optional: export to Excel ====
putexcel set "did_summary_michigan.xlsx", replace
putexcel A1=("Group") B1=("Pre mean") C1=("Post mean") D1=("Change") E1=("N_pre") F1=("N_post")
putexcel A2=("Treated") B2=`Tpre' C2=`Tpost' D2=`Tchg' E2=`TNpre' F2=`TNpost'
putexcel A3=("Control") B3=`Cpre' C3=`Cpost' D3=`Cchg' E3=`CNpre' F3=`CNpost'
putexcel A4=("DiD (ΔT−ΔC)") D4=`DID'
restore

*******************************************************************************
*CITS

* 1) If needed, aggregate to cluster-time
preserve
collapse (mean) Enrollment, by(State Year Reconnect)

scalar T0_Year = 2021

* Step 2. Compute the difference between treated and control each year

bysort Year: egen y1 = mean(cond(Reconnect==1, Enrollment, .))
bysort Year: egen y0 = mean(cond(Reconnect==0, Enrollment, .))

gen diff = y1 - y0

bysort Year: gen tag = _n==1
keep if tag
keep Year y1 y0 diff

* Step 3. Create time and treatment variables
sort Year
gen t = Year - Year[1]             // time index starting at 0
scalar T0 = T0_Year - Year[1]      // index of policy year
gen post   = (t >= T0)             // 1 if year >= policy year
gen tsince = cond(t >= T0, t - T0, 0)  // 0 before policy, 1,2,... after

* Step 4. Run Time Series break model

* Automatic Newey-West lag (for HAC robust SEs)
tsset Year

sum t
scalar T = r(max) + 1
scalar L = floor(4*(T/100)^(2/9))     // rule-of-thumb lag
display "Newey-West lag = " L

newey diff post tsince t, lag(`=L')

restore

******************************************************************************
*Parallel Trends
*****************************************************************************
gen rel_year = Year - 2021

* 5 years before treatment
gen treat_rel_m8 = (rel_year == -8 & Reconnect == 1)
gen treat_rel_m7 = (rel_year == -7 & Reconnect == 1)
gen treat_rel_m6 = (rel_year == -6 & Reconnect == 1)
gen treat_rel_m5 = (rel_year == -5 & Reconnect == 1)
gen treat_rel_m4 = (rel_year == -4 & Reconnect == 1)
gen treat_rel_m3 = (rel_year == -3 & Reconnect == 1)
gen treat_rel_m2 = (rel_year == -2 & Reconnect == 1)
* do NOT create a variable for -1 (baseline)

* POST years for Massachusetts
gen treat_rel0 = (rel_year == 0  & Reconnect == 1)
gen treat_rel1 = (rel_year == 1  & Reconnect == 1)
gen treat_rel2 = (rel_year == 2  & Reconnect == 1)
gen treat_rel3 = (rel_year == 3  & Reconnect == 1)
gen treat_rel4 = (rel_year == 4  & Reconnect == 1)
gen treat_rel5 = (rel_year == 5  & Reconnect == 1)

xtset ID Year

xtreg Enrollment ///
      treat_rel_m8 treat_rel_m7 treat_rel_m6 treat_rel_m5 treat_rel_m4 treat_rel_m3 treat_rel_m2 ///
      treat_rel0 treat_rel1 treat_rel2 treat_rel3 treat_rel4 treat_rel5 ///
      i.Year, fe cluster(ID)

test treat_rel_m6 treat_rel_m5 treat_rel_m4 treat_rel_m3 treat_rel_m2

gen fake_treat = (Reconnect == 0)
gen fake_post = (Year >= 2018)
gen fake_did = fake_treat * fake_post
reghdfe Enrollment i.fake_treat##i.fake_post, absorb(ID Year) vce(cluster ID)
*********************************************************************************
gen post  = (Year >= 2021)

tabstat Enrollment, by (Year)
bysort Year State: summarize Enrollment

preserve

* Collapse to mean, sd, and count
collapse (mean) mean_enroll=Enrollment ///
         (sd)   sd_enroll=Enrollment ///
         (count) n_enroll=Enrollment, by(Year State)

* Reshape wide so states become columns
reshape wide mean_enroll sd_enroll n_enroll, i(Year) j(State) string

* Put Year first for readability
order Year, first

* Format numbers
ds, has(type numeric)
format `r(varlist)' %9.1f

* Export to Excel (all stats)
export excel using "summary_by_year_state.xlsx", ///
    sheet("Table1") firstrow(variables) replace

restore


preserve
collapse (mean) mean_enroll=Enrollment, by(State Year)
export excel using "C:\Users\jacob\Downloads\MICHIGANOHIODATA\Cleaned and stata ready\michicansumstats.xlsx", sheet("by_state_year") firstrow(variables) replace
restore

tabstat Enrollment, by (Institution)

reg Enrollment i.Reconnect##i.post, robust
outreg2 using regressiontableMIOH.doc, replace ctitle (Without Institutional Fixed Effects) title(MIOH reg table outcomes)

xtset ID Year
xtreg Enrollment i.Reconnect##i.post
outreg2 using regressiontableMIOH.doc, append ctitle (With Institutional Fixed Effects)

********************************************************************************
reghdfe Enrollment i.Reconnect##i.post, absorb (ID Year) vce(robust)



********************************************************************************


preserve
    collapse (mean) Enrollment, by(Reconnect Year)

    twoway ///
        (line Enrollment Year if Reconnect==1, lpattern(solid) msymbol(o)) ///
        (line Enrollment Year if Reconnect==0, lpattern(dash)  msymbol(o)), ///
        legend(order(1 "Treated" 2 "Control") pos(6) col(1)) ///
        ytitle("Mean Community College 25 + Enrollment") xtitle("Year") ///
        title("Michigan & Ohio Enrollment Trends") ///
        xline(2021, lpattern(shortdash) lwidth(med)) ///
        name(did_trends, replace)

    graph export "did_trends_michigan.png", width(2000) replace
restore

ssc install estout

esttab using "did_results_michigan_ohio.rtf", replace se b(3) se(3) star(* 0.1 ** 0.05 *** 0.01)

********************************************************************************
*** Michigan Reconnect with Anticipation
*******************************************************************************
gen postant = (Year >= 2020)

reg Enrollment i.Reconnect##i.postant, robust

xtset ID Year
xtreg Enrollment i.Reconnect##i.postant, fe vce(cluster ID)
outreg2 using regressiontableMIOH.doc, append ctitle (With Anticipation Effects)

preserve
    collapse (mean) Enrollment, by(treated Year)

    twoway ///
        (line Enrollment Year if Reconnect==1, lpattern(solid) msymbol(o)) ///
        (line Enrollment Year if Reconnect==0, lpattern(dash)  msymbol(o)), ///
        legend(order(1 "Treated" 2 "Control") pos(6) col(1)) ///
        ytitle("Mean Enrollment") xtitle("Year") ///
        title("DID Michigan & Ohio") ///
        xline(2021, lpattern(shortdash) lwidth(med)) ///
        name(did_trends, replace)

    graph export "did_trends_michigan_anticipation.png", width(2000) replace
restore

