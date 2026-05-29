
*************************************************************
* Summary Statistics
*************************************************************

tab Year
tab State
tab Reconnect

gen post = (Year >= 2021)

tabstat Enrollment, by(Year)
bysort Year State: summarize Enrollment

preserve
collapse (mean) mean_enroll=Enrollment ///
         (sd) sd_enroll=Enrollment 
         (count) n_enroll=Enrollment, by(Year State)
list, sepby(State)
restore

*************************************************************
* Main DiD
*************************************************************

reghdfe Enrollment i.Reconnect##i.post, absorb(ID Year) vce(robust)

*************************************************************
* Anticipation DiD
*************************************************************

gen postant = (Year >= 2020)

reghdfe Enrollment i.Reconnect##i.postant, absorb(ID Year) vce(robust)

*************************************************************
* Comparative Interrupted Time Series
*************************************************************

preserve

collapse (mean) Enrollment, by(State Year Reconnect)

scalar T0_Year = 2021

bysort Year: egen y1 = mean(cond(Reconnect==1, Enrollment, .))
bysort Year: egen y0 = mean(cond(Reconnect==0, Enrollment, .))

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

gen rel_year = Year - 2021

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

xtset ID Year

xtreg Enrollment ///
      treat_rel_m8 treat_rel_m7 treat_rel_m6 treat_rel_m5 treat_rel_m4 treat_rel_m3 treat_rel_m2 ///
      treat_rel0 treat_rel1 treat_rel2 treat_rel3 treat_rel4 treat_rel5 ///
      i.Year, fe cluster(ID)

test treat_rel_m6 treat_rel_m5 treat_rel_m4 treat_rel_m3 treat_rel_m2

*************************************************************
* Placebo Test
*************************************************************

gen fake_treat = (Reconnect == 0)
gen fake_post = (Year >= 2018)
gen fake_did = fake_treat * fake_post

reghdfe Enrollment i.fake_treat##i.fake_post, absorb(ID Year) vce(cluster ID)

*************************************************************
* Enrollment Trends Graph
*************************************************************

preserve

collapse (mean) Enrollment, by(Reconnect Year)

twoway ///
    (line Enrollment Year if Reconnect==1, lpattern(solid) msymbol(o)) ///
    (line Enrollment Year if Reconnect==0, lpattern(dash) msymbol(o)), ///
    legend(order(1 "Treated" 2 "Control") pos(6) col(1)) ///
    ytitle("Mean Community College 25+ Enrollment") ///
    xtitle("Year") ///
    title("Michigan & Ohio Enrollment Trends") ///
    xline(2021, lpattern(shortdash) lwidth(med)) ///
    name(did_trends, replace)

graph export "did_trends_michigan.png", width(2000) replace

restore
