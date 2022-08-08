
-- Career Outcome Table: 
-- Q1: Program breakdown: Display the ranking of career outcome rates for all the programs in SPS

WITH t1 AS (
    SELECT 
        program_name,
        COUNT(DISTINCT student_id) AS outcome_num
    FROM career_outcome
    LEFT JOIN student USING (student_id)
    LEFT JOIN program USING (program_id)
    WHERE job_type IN ('Job','Internship','Own Venture','Service Organization','Research','Military Service','Fellowship')
	GROUP BY program_name
),
t2 AS (
    SELECT 
		program_name,
        COUNT(DISTINCT student_id) AS total_num
    FROM career_outcome
    LEFT JOIN student USING (student_id)
    LEFT JOIN program USING (program_id)
    GROUP BY program_name
)
SELECT 
	program_name,
	career_outcome_rate,
	RANK() OVER(ORDER BY career_outcome_rate DESC) AS rk
FROM (
	SELECT 
		t1.program_name,
		outcome_num,
		total_num,
		ROUND((outcome_num*100.00/total_num)/100.00, 4) AS career_outcome_rate,
		RANK() OVER(ORDER BY ROUND((outcome_num*100.00/total_num)/100.00, 4) DESC) AS rk
	FROM t1
	JOIN t2 ON t1.program_name = t2.program_name
) t
WHERE rk <= 10;

-- Q2: Graduation term breakdown: Display the employment status (career outcome rate and seeking employment rate) 
--     for all the available graduation classes  

WITH t1 AS (
    SELECT 
		graduation_year,
		graduation_term,		
        COUNT(DISTINCT student_id) AS seeking_num
    FROM career_outcome
    LEFT JOIN student USING (student_id)
    LEFT JOIN program USING (program_id)
    WHERE job_type IN ('Still Seeking Employment', 'Still Seeking Internship')
	GROUP BY graduation_year, graduation_term
),
t2 AS (
    SELECT 
		graduation_year,
		graduation_term,
        COUNT(DISTINCT student_id) AS outcome_num
    FROM career_outcome
    LEFT JOIN student USING (student_id)
    LEFT JOIN program USING (program_id)
    WHERE job_type IN ('Job','Internship','Own Venture','Service Organization','Research','Military Service','Fellowship')
	GROUP BY graduation_year, graduation_term
),
t3 AS (
    SELECT 
		graduation_year,
		graduation_term,
        COUNT(DISTINCT student_id) AS total_num
    FROM career_outcome
    LEFT JOIN student USING (student_id)
    LEFT JOIN program USING (program_id)
	GROUP BY graduation_year, graduation_term
)
SELECT 
	t1.graduation_year,
	t1.graduation_term,
	t1.seeking_num,
	t2.outcome_num,
	t3.total_num,
	ROUND((t1.seeking_num*100.00 / t3.total_num)/100.00, 4) AS seeking_employement_rate,
	ROUND((t2.outcome_num*100.00 / t3.total_num)/100.00, 4) AS  career_outcome_rate
FROM t1
JOIN t2 ON t1.graduation_year = t2.graduation_year AND t1.graduation_term = t2.graduation_term
JOIN t3 ON t1.graduation_year = t3.graduation_year AND t1.graduation_term = t3.graduation_term;


-- Q3: Show the top 10 cities of employments for the whole SPS

SELECT 
	work_city, student_number, rk
FROM (
	SELECT work_city, 
		COUNT(DISTINCT student_id) AS student_number,
		RANK() OVER(ORDER BY COUNT(DISTINCT student_id) DESC) AS rk
	FROM career_outcome
	LEFT JOIN industry USING(industry_id)
	LEFT JOIN student USING (student_id)
	LEFT JOIN program USING (program_id)
	WHERE program_name = 'Applied Analytics'
	GROUP BY work_city
) t1
WHERE rk <= 10
ORDER BY rk, work_city;


-- Q4: Show the industry distribution

SELECT industry_name, COUNT(DISTINCT student_id) AS student_number
FROM career_outcome
LEFT JOIN industry USING(industry_id)
LEFT JOIN student USING (student_id)
LEFT JOIN program USING (program_id)
WHERE true
        [[ AND {{program}} ]]
        [[ AND {{graduation_year}} ]]
        [[ AND {{graduation_term}} ]]
GROUP BY industry_name
ORDER BY student_number DESC
LIMIT 10;


-- Event Table: 
-- Q5: Any trends between event date and time with registration rate? For example, events hosted at a certain 
--     time period in a day tend to have more registrations (Find the best day in a week and best time of the
--     day to host events)

-- The change of average registration rate in a week: 

WITH t1 AS (
	SELECT  
		EXTRACT(isodow FROM start_date) AS day_of_the_week,
		start_time,
		start_date,
		event_name,
		event_type,
		student_id
	FROM registration 
	LEFT JOIN career_event USING (event_id)
	WHERE true
	    [[ AND {{start_date}} ]]
        [[ AND {{event_type}} ]]
)
SELECT day_of_the_week,
	ROUND(AVG(regis_rate), 2) AS avg_registration_rate
FROM (
	SELECT 
		day_of_the_week,
		event_name,
		COUNT(DISTINCT student_id) AS regis_num,
		ROUND((COUNT(DISTINCT student_id)*100.00 / (SELECT COUNT(DISTINCT student_id) FROM student))/100, 4) AS regis_rate
	FROM t1
	GROUP BY day_of_the_week, event_name
) t2
GROUP BY day_of_the_week
ORDER BY day_of_the_week;


-- The change of average registration rate in a day: 

WITH t1 AS (
	SELECT
		EXTRACT(HOUR FROM start_time) AS new_time,
		start_date,
		event_name,
		event_type,
		student_id
	FROM registration 
	LEFT JOIN career_event USING (event_id)
	WHERE true 
        [[ AND {{start_date}} ]]
        [[ AND {{event_type}} ]]
)
SELECT new_time,
	ROUND(AVG(regis_rate), 2) AS avg_registration_rate
FROM (
	SELECT 
		new_time,
		event_name,
		COUNT(DISTINCT student_id) AS regis_num,
		ROUND((COUNT(DISTINCT student_id)*100.00 / (SELECT COUNT(DISTINCT student_id) FROM student))/100, 4) AS regis_rate
	FROM t1
	GROUP BY new_time, event_name
) t2
GROUP BY new_time
ORDER BY new_time;


-- Q6: What are some popular career events? (Show the top 10 events using their average rate of registrations) 

SELECT
    event_name,
    regis_num,
    total_num,
    ROUND((regis_num*100.00 / total_num)/100, 4) AS registration_rate
FROM (    
    SELECT 
        event_name, 
        COUNT(DISTINCT student_id) AS regis_num,
        (SELECT COUNT(DISTINCT student_id) FROM student) AS total_num
    FROM registration
    LEFT JOIN career_event USING (event_id)
    WHERE true 
        [[ AND {{start_date}} ]]
        [[ AND {{event_type}} ]]
    GROUP BY event_name
) t1
GROUP BY event_name, regis_num, total_num
ORDER BY registration_rate DESC
LIMIT 10;


-- Appointment Table: 
-- Q7: Show the top 10 appointment type

WITH t1 AS (
	SELECT 
		COUNT(DISTINCT student_id) AS total_num
	FROM appointment
    LEFT JOIN advisor USING (advisor_id)
    LEFT JOIN student USING (student_id)
    LEFT JOIN program ON student.program_id = program.program_id
    WHERE true 
        [[ AND {{appointment_date}} ]]
        [[ AND {{adv_uni}} ]]
        [[ AND {{program_name}} ]]
),
t2 AS (
	SELECT 
		appointment_type,
		COUNT(DISTINCT student_id) AS app_num
	FROM appointment
    LEFT JOIN advisor USING (advisor_id)
    LEFT JOIN student USING (student_id)
    LEFT JOIN program ON student.program_id = program.program_id
    WHERE true 
        [[ AND {{appointment_date}} ]]
        [[ AND {{adv_uni}} ]]
        [[ AND {{program_name}} ]]
	GROUP BY appointment_type
)
SELECT 
	appointment_type,
	app_num,
	total_num,
	registration_rate,
	rk
FROM (	
	SELECT 
		t2.appointment_type,
		t2.app_num,
		(SELECT t1.total_num FROM t1) AS total_num,
		ROUND((t2.app_num*100.00 / (SELECT total_num FROM t1))/100, 4) AS registration_rate,
		RANK() OVER(ORDER BY ROUND((t2.app_num*100.00 / (SELECT total_num FROM t1))/100, 4) DESC, t2.appointment_type) AS rk
    FROM t2
) t
WHERE rk <= 10;


-- Q8: Timeline: show the change of appointment registrations in a year (This analysis could help CDL better
--     allocate teaching resources, ie: arranging more advisors in the busy season)
SELECT 
    app_month,
    COUNT(student_id) AS app_num
FROM (
    SELECT
        EXTRACT(month from appointment_date) AS app_month,
        student_id,
        advisor_id,
        appointment_type
    FROM appointment
    LEFT JOIN advisor USING (advisor_id)
    LEFT JOIN student USING (student_id)
    LEFT JOIN program ON student.program_id = program.program_id
    WHERE true 
        [[ AND {{appointment_date}} ]]
        [[ AND {{appointment_type}} ]]
        [[ AND {{adv_uni}} ]]
        [[ AND {{program_name}} ]]
        
) t1 
GROUP BY app_month
ORDER BY app_month;


-- Q9: Top 3 appointment types across programs. Do certain appointment types be preferred by some programs?
--     From this result, we can help CDL to better distribute teaching resources

WITH t1 AS (
	SELECT 
		program_name,
		COUNT(DISTINCT student_id) AS total_num
	FROM appointment
	LEFT JOIN student USING (student_id)
	JOIN program USING (program_id)
	WHERE true
	    [[ AND {{program_name}} ]]
	GROUP BY program_name
),
t2 AS (
	SELECT 
		program_name,
		appointment_type,
		COUNT(DISTINCT student_id) AS app_num
	FROM appointment
	LEFT JOIN student USING (student_id)
	JOIN program USING (program_id)
	WHERE true
	    [[ AND {{program_name}} ]]
	GROUP BY program_name, appointment_type
)
SELECT 
	program_name,
	appointment_type,
	rk
FROM (	
	SELECT 
		t2.program_name, 
		t2.appointment_type,
		t1.total_num,
		t2.app_num,
		ROUND((t2.app_num*100.00 / t1.total_num)/100, 4) AS registration_rate,
		RANK() OVER(PARTITION BY t2.program_name ORDER BY ROUND((t2.app_num*100.00 / t1.total_num)/100, 4) DESC, appointment_type) AS rk
	FROM t2
	LEFT JOIN t1 ON t2.program_name = t1.program_name
) t
WHERE rk <= 3;


-- Online courses:
-- Q10: What are the top 10 rating online courses? 

SELECT course_title, rating, price
FROM (
SELECT 
	course_title,
	rating,
	price,
	DENSE_RANK() OVER(ORDER BY rating DESC) AS rk
FROM online_course
) t
WHERE rk = 1
ORDER BY rating DESC, price;

