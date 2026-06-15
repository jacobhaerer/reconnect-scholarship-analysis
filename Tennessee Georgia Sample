*************************************************************
* Summary Statistics
*************************************************************

tab Year
tab State
tab Reconnect

gen post = (Year >= 2018)

tabstat EnrollmentSUM, by(Year)
bysort Year State: summarize EnrollmentSUM

preserve
collapse (mean) mean_enroll=EnrollmentSUM ///
         (sd) sd_enroll=EnrollmentSUM ///
         (count) n_enroll=EnrollmentSUM, by(Year State)
list, sepby(State)
restore

*************************************************************
* Main DiD
*************************************************************

reghdfe EnrollmentSUM i.Reconnect##i.post, absorb(UnitID Year) vce(cluster UnitID)

*************************************************************
* Anticipation DiD
*************************************************************

gen postant = (Year >= 2017)

reghdfe EnrollmentSUM i.Reconnect##i.postant, absorb(UnitID Year) vce(cluster UnitID)

*************************************************************
* Comparative Interrupted Time Series
*************************************************************

preserve

collapse (mean) EnrollmentSUM, by(State Year Reconnect)

scalar T0_Year = 2018

bysort Year: egen y1 = mean(cond(Reconnect==1, EnrollmentSUM, .))
bysort Year: egen y0 = mean(cond(Reconnect==0, EnrollmentSUM, .))

gen diff = y1 - y0

bysort Year: gen tag = _n==1
keep if tag
keep Year y1 y0 diff

sort Year
gen t = Year - Year[1]
scalar T0 = T0_Year - Year[1]
gen post = (t >= T0)
gen tsince = cond(t >= T0, t - T0, 0)

tsset Year

sum t
scalar T = r(max) + 1
scalar L = floor(4*(T/100)^(2/9))

newey diff post tsince t, lag(`=L')

restore

*************************************************************
* Parallel Trends
*************************************************************

gen rel_year = Year - 2018

gen treat_rel_m8 = (rel_year == -8 & Reconnect == 1)
gen treat_rel_m7 = (rel_year == -7 & Reconnect == 1)
gen treat_rel_m6 = (rel_year == -6 & Reconnect == 1)
gen treat_rel_m5 = (rel_year == -5 & Reconnect == 1)
gen treat_rel_m4 = (rel_year == -4 & Reconnect == 1)
gen treat_rel_m3 = (rel_year == -3 & Reconnect == 1)
gen treat_rel_m2 = (rel_year == -2 & Reconnect == 1)

* rel_year == -1 is omitted as the baseline category

gen treat_rel0 = (rel_year == 0 & Reconnect == 1)
gen treat_rel1 = (rel_year == 1 & Reconnect == 1)
gen treat_rel2 = (rel_year == 2 & Reconnect == 1)
gen treat_rel3 = (rel_year == 3 & Reconnect == 1)
gen treat_rel4 = (rel_year == 4 & Reconnect == 1)
gen treat_rel5 = (rel_year == 5 & Reconnect == 1)

xtset UnitID Year

xtreg EnrollmentSUM ///
      treat_rel_m8 treat_rel_m7 treat_rel_m6 treat_rel_m5 treat_rel_m4 treat_rel_m3 treat_rel_m2 ///
      treat_rel0 treat_rel1 treat_rel2 treat_rel3 treat_rel4 treat_rel5 ///
      i.Year, fe cluster(UnitID)

test treat_rel_m6 treat_rel_m5 treat_rel_m4 treat_rel_m3 treat_rel_m2

*************************************************************
* Placebo Test
*************************************************************

gen fake_treat = (Reconnect == 0)
gen fake_post = (Year >= 2016)
gen fake_did = fake_treat * fake_post

reghdfe EnrollmentSUM i.fake_treat##i.fake_post, absorb(UnitID Year) vce(cluster UnitID)

*************************************************************
* Short-Term Effects
*************************************************************

preserve

drop if Year > 2019

reghdfe EnrollmentSUM i.Reconnect##i.post, absorb(UnitID Year) vce(cluster UnitID)

restore

*************************************************************
* Enrollment Trends Graph
*************************************************************

preserve

collapse (mean) EnrollmentSUM, by(Reconnect Year)

twoway ///
    (line EnrollmentSUM Year if Reconnect==1, lpattern(solid) msymbol(o)) ///
    (line EnrollmentSUM Year if Reconnect==0, lpattern(dash) msymbol(o)), ///
    legend(order(1 "Treated" 2 "Control") pos(6) col(1)) ///
    ytitle("Mean Community College 22+ Enrollment") ///
    xtitle("Year") ///
    title("Tennessee & Georgia Enrollment Trends") ///
    xline(2018, lpattern(shortdash) lwidth(med)) ///
    name(did_trends, replace)

graph export "did_trends_tennessee.png", width(2000) replace

restore
