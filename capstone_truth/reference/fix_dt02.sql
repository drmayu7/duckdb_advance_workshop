-- DQ FIX: DT02 (Angle C). Hospital Queen Elizabeth (11-12060025), on Sabah's
-- old HIS, exports every date month first (MM/DD/YYYY); the rest of the old HIS
-- writes DD/MM/YYYY. C4 reads a day after the 12th as no date at all, and an
-- earlier one as the wrong month, so the hospital's stays, bed days and 2021
-- admissions go wrong. Rewrite that hospital's dates day first, in the RAW
-- stage, before C4 types them. Runs on admission_raw.
--
-- How a team finds it: NULL admit dates after C4 (want 0) all come from one
-- facility; its bed days against 2020 are implausible.
UPDATE admission_raw
SET dob = strftime(strptime(dob, '%m/%d/%Y'), '%d/%m/%Y'),
    admit_date = strftime(strptime(admit_date, '%m/%d/%Y'), '%d/%m/%Y'),
    discharge_date = strftime(strptime(discharge_date, '%m/%d/%Y'), '%d/%m/%Y'),
    updated_at = strftime(strptime(updated_at, '%m/%d/%Y %H:%M'), '%d/%m/%Y %H:%M')
WHERE source_system = 'old_his' AND facility_code = '11-12060025';
