*************************************************************
* Summary Statistics/ Setup - 
*************************************************************

tab Year
tab State
tab Reconnect

capture drop event_time immediate yearafter post did

gen event_time = Year - Imp_Year
gen byte immediate = (event_time == 0 & Reconnect == 1)
gen byte yearafter = (event_time == 1 & Reconnect == 1)
gen byte post = event_time >= 0
gen byte did = Reconnect * post

tab event_time
tab event_time Reconnect

summarize Enrollment Reconnect post did immediate yearafter event_time

tabstat Enrollment, by(Reconnect) stat(n mean sd min max)
tabstat Enrollment, by(Reconnect post) stat(n mean sd)

*************************************************************
* Pooled DiD: Immediate and Year-After Effects
*************************************************************

reghdfe Enrollment immediate yearafter i.Year, absorb(ID) vce(cluster State)

boottest immediate yearafter, cluster(State) reps(9999) seed(12345)
boottest immediate, cluster(State) reps(9999) seed(12345)
boottest yearafter, cluster(State) reps(9999) seed(12345)

*************************************************************
* Parallel Trends / Event Study
*************************************************************

capture drop evtm5 evtm4 evtm3 evtm2 evt0 evt1 evt2 evt3

gen evtm5 = (event_time == -5) & Reconnect == 1
gen evtm4 = (event_time == -4) & Reconnect == 1
gen evtm3 = (event_time == -3) & Reconnect == 1
gen evtm2 = (event_time == -2) & Reconnect == 1
* event_time == -1 is omitted as the baseline

gen evt0  = (event_time == 0) & Reconnect == 1
gen evt1  = (event_time == 1) & Reconnect == 1
gen evt2  = (event_time == 2) & Reconnect == 1
gen evt3  = (event_time == 3) & Reconnect == 1

reghdfe Enrollment evtm5 evtm4 evtm3 evtm2 evt0 evt1 evt2 evt3 i.Year, ///
    absorb(ID) vce(cluster State)

test evtm5 evtm4 evtm3 evtm2

*************************************************************
* Event-Time Enrollment Trends Graph
*************************************************************

capture drop event_time_fake
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
    xtitle("Years Relative to Treatment") ///
    ytitle("Mean Adult Enrollment") ///
    xline(0, lcolor(black)) ///
    xlabel(-5(1)1) ///
    title("Treatment and Control Enrollment Trends")

restore
