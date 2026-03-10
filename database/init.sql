CREATE DATABASE IF NOT EXISTS huskyhub;
USE huskyhub;

-- ─────────────────────────────────────────
-- Tables
-- ─────────────────────────────────────────

CREATE TABLE IF NOT EXISTS users (
    user_id    INT AUTO_INCREMENT PRIMARY KEY,
    username   VARCHAR(64)  NOT NULL UNIQUE,
    first_name VARCHAR(64)  NOT NULL,
    last_name  VARCHAR(64)  NOT NULL,
    email      VARCHAR(128) NOT NULL UNIQUE,
    password   VARCHAR(255) NOT NULL,
    role       ENUM('student', 'advisor', 'admin') NOT NULL DEFAULT 'student',
    approved   TINYINT(1) NOT NULL DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS courses (
    course_id   INT AUTO_INCREMENT PRIMARY KEY,
    course_code VARCHAR(16)  NOT NULL,
    course_name VARCHAR(128) NOT NULL,
    credits     INT NOT NULL DEFAULT 4,
    instructor  VARCHAR(64)
);

CREATE TABLE IF NOT EXISTS grades (
    grade_id    INT AUTO_INCREMENT PRIMARY KEY,
    student_id  INT NOT NULL,
    course_id   INT NOT NULL,
    grade       VARCHAR(4) NOT NULL,
    gpa_points  DECIMAL(3,1) NOT NULL,
    quarter     VARCHAR(32) NOT NULL,
    FOREIGN KEY (student_id) REFERENCES users(user_id) ON DELETE CASCADE,
    FOREIGN KEY (course_id)  REFERENCES courses(course_id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS enrollments (
    enrollment_id INT AUTO_INCREMENT PRIMARY KEY,
    student_id    INT NOT NULL,
    course_id     INT NOT NULL,
    quarter       VARCHAR(32) NOT NULL,
    status        ENUM('enrolled', 'waitlisted', 'dropped') NOT NULL DEFAULT 'enrolled',
    FOREIGN KEY (student_id) REFERENCES users(user_id) ON DELETE CASCADE,
    FOREIGN KEY (course_id)  REFERENCES courses(course_id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS messages (
    message_id   INT AUTO_INCREMENT PRIMARY KEY,
    sender_id    INT NOT NULL,
    recipient_id INT NOT NULL,
    subject      VARCHAR(255) NOT NULL,
    body         TEXT,
    is_read      TINYINT(1) NOT NULL DEFAULT 0,
    sent_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (sender_id)    REFERENCES users(user_id) ON DELETE CASCADE,
    FOREIGN KEY (recipient_id) REFERENCES users(user_id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS advising_notes (
    note_id      INT AUTO_INCREMENT PRIMARY KEY,
    student_id   INT NOT NULL,
    advisor_id   INT NOT NULL,
    note_content TEXT,
    created_at   TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (student_id)  REFERENCES users(user_id) ON DELETE CASCADE,
    FOREIGN KEY (advisor_id)  REFERENCES users(user_id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS documents (
    doc_id      INT AUTO_INCREMENT PRIMARY KEY,
    user_id     INT NOT NULL,
    filename    VARCHAR(255) NOT NULL,
    file_path   VARCHAR(512) NOT NULL,
    doc_type    VARCHAR(64),
    uploaded_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE
);

-- ─────────────────────────────────────────
-- Users
-- Passwords stored in plaintext (Week 3 vulnerability)
-- ─────────────────────────────────────────

INSERT INTO users (user_id, username, first_name, last_name, email, password, role, approved) VALUES
    (1,  'admin',     'Admin',   'User',    'admin@huskyhub.uw.edu',     'admin',          'admin',   1),
    (2,  'mwilson',   'Morgan',  'Wilson',  'mwilson@uw.edu',            'advisor123',     'advisor', 1),
    (3,  'jsmith',    'Jamie',   'Smith',   'jsmith@uw.edu',             'password123',    'student', 1),
    (4,  'alee',      'Alex',    'Lee',     'alee@uw.edu',               'alexpass',       'student', 1),
    (5,  'pchen',     'Priya',   'Chen',    'pchen@uw.edu',              'priya2024',      'student', 1),
    (6,  'tbrown',    'Tyler',   'Brown',   'tbrown@uw.edu',             'tyler99',        'student', 1),
    (7,  'sgarcia',   'Sofia',   'Garcia',  'sgarcia@uw.edu',            'sofia!123',      'student', 1),
    (8,  'dkim',      'David',   'Kim',     'dkim@uw.edu',               'dkim2025',       'student', 1),
    (9,  'rnguyen',   'Rachel',  'Nguyen',  'rnguyen@uw.edu',            'rachel456',      'student', 1),
    (10, 'cmartinez', 'Carlos',  'Martinez','cmartinez@uw.edu',          'carlos789',      'student', 1),
    (11, 'lthompson', 'Lauren',  'Thompson','lthompson@uw.edu',          'lauren!pass',    'student', 1),
    (12, 'pending1',  'Sam',     'Jordan',  'sjordan@uw.edu',            'newuser',        'student', 0);

-- ─────────────────────────────────────────
-- Courses
-- ─────────────────────────────────────────

INSERT INTO courses (course_id, course_code, course_name, credits, instructor) VALUES
    (1, 'INFO 200',  'Intellectual Foundations of Informatics',  4, 'Dr. Park'),
    (2, 'INFO 201',  'Technical Foundations of Informatics',      4, 'Prof. Hayes'),
    (3, 'INFO 310',  'Information Assurance and Cybersecurity',   4, 'Andy Herman'),
    (4, 'INFO 330',  'Databases and Data Modeling',               4, 'Dr. Ruiz'),
    (5, 'INFO 340',  'Client-Side Development',                   4, 'Prof. Kim'),
    (6, 'INFO 350',  'Information Ethics and Policy',             4, 'Dr. Olsen'),
    (7, 'INFO 360',  'Design Methods',                            4, 'Prof. Tran'),
    (8, 'INFO 380',  'Product and Startup Development',           4, 'Dr. Patel'),
    (9, 'INFO 430',  'Database Design and SQL',                   4, 'Dr. Ruiz'),
    (10,'INFO 442',  'Cooperative Software Development',          4, 'Prof. Lee');

-- ─────────────────────────────────────────
-- Grades
-- ─────────────────────────────────────────

INSERT INTO grades (student_id, course_id, grade, gpa_points, quarter) VALUES
    -- jsmith (3)
    (3, 1, 'A',  4.0, 'Autumn 2023'),
    (3, 2, 'A-', 3.7, 'Autumn 2023'),
    (3, 3, 'B+', 3.3, 'Winter 2024'),
    (3, 4, 'A',  4.0, 'Winter 2024'),
    (3, 5, 'B',  3.0, 'Spring 2024'),
    -- alee (4)
    (4, 1, 'B+', 3.3, 'Autumn 2023'),
    (4, 2, 'B',  3.0, 'Autumn 2023'),
    (4, 3, 'A',  4.0, 'Winter 2024'),
    (4, 6, 'A-', 3.7, 'Spring 2024'),
    -- pchen (5)
    (5, 1, 'A',  4.0, 'Autumn 2023'),
    (5, 2, 'A',  4.0, 'Autumn 2023'),
    (5, 4, 'A-', 3.7, 'Winter 2024'),
    (5, 5, 'A',  4.0, 'Spring 2024'),
    -- tbrown (6)
    (6, 1, 'C+', 2.3, 'Autumn 2023'),
    (6, 2, 'B-', 2.7, 'Autumn 2023'),
    (6, 3, 'C',  2.0, 'Winter 2024'),
    -- sgarcia (7)
    (7, 1, 'A-', 3.7, 'Autumn 2023'),
    (7, 3, 'B+', 3.3, 'Winter 2024'),
    (7, 7, 'A',  4.0, 'Spring 2024'),
    -- dkim (8)
    (8, 2, 'B+', 3.3, 'Autumn 2023'),
    (8, 4, 'A',  4.0, 'Winter 2024'),
    (8, 9, 'A-', 3.7, 'Spring 2024'),
    -- rnguyen (9)
    (9, 1, 'B',  3.0, 'Autumn 2023'),
    (9, 5, 'B+', 3.3, 'Winter 2024'),
    (9, 6, 'A',  4.0, 'Spring 2024'),
    -- cmartinez (10)
    (10, 2, 'A', 4.0, 'Autumn 2023'),
    (10, 3, 'B', 3.0, 'Winter 2024'),
    (10, 8, 'A', 4.0, 'Spring 2024'),
    -- lthompson (11)
    (11, 1, 'A-', 3.7, 'Autumn 2023'),
    (11, 4, 'B+', 3.3, 'Winter 2024'),
    (11, 10,'A',  4.0, 'Spring 2024');

-- ─────────────────────────────────────────
-- Enrollments (current quarter)
-- ─────────────────────────────────────────

INSERT INTO enrollments (student_id, course_id, quarter, status) VALUES
    (3,  6,  'Spring 2025', 'enrolled'),
    (3,  7,  'Spring 2025', 'enrolled'),
    (4,  7,  'Spring 2025', 'enrolled'),
    (4,  8,  'Spring 2025', 'enrolled'),
    (5,  6,  'Spring 2025', 'enrolled'),
    (5,  8,  'Spring 2025', 'waitlisted'),
    (6,  5,  'Spring 2025', 'enrolled'),
    (7,  9,  'Spring 2025', 'enrolled'),
    (8,  10, 'Spring 2025', 'enrolled'),
    (9,  9,  'Spring 2025', 'waitlisted'),
    (10, 10, 'Spring 2025', 'enrolled');

-- ─────────────────────────────────────────
-- Messages
-- Note: one message contains stored XSS payload (Week 8 target)
-- ─────────────────────────────────────────

INSERT INTO messages (sender_id, recipient_id, subject, body, is_read) VALUES
    (2, 3,  'Welcome to Spring Quarter',
     'Hi Jamie, welcome back! Let me know if you need anything this quarter.',
     0),
    (3, 2,  'Grade question',
     'Hi Morgan, I had a question about my INFO 310 grade from last quarter.',
     1),
    (2, 4,  'Enrollment reminder',
     'Alex, please make sure to finalize your Spring enrollment by Friday.',
     0),
    (4, 3,  'Study group?',
     'Hey Jamie, want to form a study group for INFO 340?',
     0),
    (2, 5,  'Academic standing',
     'Priya, your academic standing looks great. Keep up the excellent work!',
     0);

-- ─────────────────────────────────────────
-- Advising Notes
-- Note: one note contains stored XSS payload (Week 8 target)
-- ─────────────────────────────────────────

INSERT INTO advising_notes (student_id, advisor_id, note_content) VALUES
    (3, 2, 'Jamie is on track for graduation in Spring 2026. Recommend taking INFO 380 next quarter.'),
    (4, 2, 'Alex expressed interest in the data science track. Reviewed prerequisite sequence.'),
    (5, 2, 'Priya is performing exceptionally. Nominated for departmental honors.'),
    (6, 2, 'Tyler is struggling in technical courses. Referred to academic support services. Follow up next month.'),
    (7, 2, 'Sofia has strong design skills. Suggested INFO 360 and INFO 380 sequence.');
