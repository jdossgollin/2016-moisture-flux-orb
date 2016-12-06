rm(list = ls())
load('processed/amo.rda')
load('processed/pna.rda')
load('processed/moisture.rda')
load('processed/dipole_ts.rda')

setnames(dipole, 'date', 'time')

mrg <- merge(dipole, q_mean, by = 'time')
mrg[, date := as_date(time)]
mrg <- merge(mrg, pna[, .(date, pna)], by = 'date')
mrg[, ':='(year = year(date), month = month(date))]
mrg <- merge(mrg, amo[, .(year, month, amo)], by = c('year', 'month'))

mrg <- mrg[, .(time, date, dipole, dq, pna, amo)]
pairs(mrg[, .(dipole, dq, pna, amo)], pch = '.')
