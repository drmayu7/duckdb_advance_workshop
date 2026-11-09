# Capstone Hint cards

**Facilitator only. Not in any release.** Give a team its Angle's card at **10.30 on Day 3** if it has not yet named a suspect. Each card describes a **symptom** the team can check for itself, never the cause or the fix. Cut along the lines.

---

## Hint card · Angle A (readmission)

Compare the number of people in 2021 with the number of patients your pipeline ends up with.

- In Sabah, your 2021 diabetes **index episodes** are well below what its admissions suggest.
- Look at the **patient with the most admissions** in your `episode` or `admission_clean` table. How many does that patient have? Is that one person?

---

## Hint card · Angle B (dengue)

Your 2021 dengue rate is **lower than 2020 in almost every state**, often by a third or more.

- A drop that broad, in every state at once, rarely comes from the disease.
- Compare your 2021 **principal diagnoses** with 2020's in the `admission_clean` Checkpoint: which values are new in 2021?

---

## Hint card · Angle C (hospital load)

One of **Sabah's** biggest hospitals has **several times its 2020 bed days** in 2021, with no matching rise in admissions.

- Look at that hospital's stays one by one: how long are they? Some come out **months long**.
- How many of its admissions have **no admission date** after C4?
