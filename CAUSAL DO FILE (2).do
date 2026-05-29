
tab Year


gen event_time = Year - Imp_Year

gen byte immediate = (event_time == 0 & Reconnect == 1) 
gen byte yearafter = (event_time == 1 & Reconnect == 1) 

xtset ID Year

gen post = event_time>=0

gen did = Reconnect * post

reghdfe Enrollment immediate yearafter i.Year, absorb(ID) vce(cluster State)

ssc install boottest

boottest immediate yearafter, cluster(State) reps(9999) seed(12345)

boottest immediate, cluster(State) reps(9999) seed(12345)

boottest yearafter, cluster(State) reps(9999) seed(12345)

gen byte post_treat_2yrs = inlist(event_time, 0, 1) & Reconnect == 1
reghdfe Enrollment post_treat_2yrs i.Year, absorb(ID) vce(cluster State)
boottest post_treat_2yrs, cluster(State) reps(9999) seed(12345)

***********
*Parallel Trends
***********
gen evtm5 = (event_time == -5) & Reconnect == 1
gen evtm4 = (event_time == -4) & Reconnect == 1
gen evtm3 = (event_time == -3) & Reconnect == 1
gen evtm2 = (event_time == -2) & Reconnect == 1
* Do NOT generate evtm1 — it will be the omitted (baseline) category

gen evt0  = (event_time == 0)  & Reconnect == 1
gen evt1  = (event_time == 1)  & Reconnect == 1
gen evt2  = (event_time == 2)  & Reconnect == 1
gen evt3  = (event_time == 3)  & Reconnect == 1
reghdfe Enrollment evtm5 evtm4 evtm3 evtm2 evt0 evt1 evt2 evt3 i.Year, ///
    absorb(ID) vce(cluster State)
	
test evtm5 evtm4 evtm3 evtm2

*******************************************************************************

gen event_time_fake = Year - Fake_Imp_Year


preserve

drop if event_time_fake < -5
drop if event_time_fake > 1
collapse (mean) Enrollment, by(event_time_fake Reconnect)

twoway ///
    (line Enrollment event_time_fake if Reconnect==1, ///
        lwidth(medthick) lcolor(blue) msymbol(O)) ///
    (line Enrollment event_time_fake if Reconnect==0, ///
        lpattern(dash) lcolor(red) msymbol(D)), ///
    legend(order(1 "Treated states" 2 "Control states")) ///
    xtitle("Years Relative to Treatment (Event Time)") ///
    ytitle("Mean Enrollment") ///
    xline(0, lcolor(black)) ///
    xlabel(-5(1)1) ///
    title("Treatment & Control Enrollment Trends")

restore