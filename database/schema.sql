-- =====================================================================
-- YogSetu — Proposed Database Schema (MySQL 8.x / InnoDB)
--
-- Derived from a full read-through of the public site (index, teachers,
-- signup, requirements, teacher-profile...) and all three dashboards
-- (Client, Teacher, Admin). Normalized to 3NF, with BCNF-clean junction
-- tables for every many-to-many relationship.
--
-- Design rules followed throughout:
--   1. No repeating groups. Every multi-valued attribute (a teacher's
--      expertise tags, certifications, online-class locations, package
--      pricing rows; a requirement's preferred time slots) lives in its
--      own child table, never as a delimited string in a parent column.
--   2. No derived data stored alongside its source. Average student
--      rating, applicant counts, and wallet balances are computed with
--      a query (see the comments beside ratings, requirement_applications
--      and wallet_transactions) — never cached in a column that could
--      drift out of sync with the rows it summarizes.
--   3. Geography is a lookup chain (countries → states → cities), not
--      three repeated free-text columns per person/requirement.
--   4. Shared account concerns (auth, status, role) live once in
--      `users`; role-specific attributes live in one extension table
--      per role (class-table inheritance) rather than a single wide
--      table full of nullable columns.
--   5. Every FK has an explicit ON DELETE behavior — nothing is left
--      to the default, so referential integrity can't silently break.
-- =====================================================================

SET FOREIGN_KEY_CHECKS = 0;

-- ---------------------------------------------------------------------
-- 1. GEOGRAPHY
-- ---------------------------------------------------------------------

CREATE TABLE countries (
  id          BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  name        VARCHAR(100) NOT NULL,
  UNIQUE KEY uq_countries_name (name)
) ENGINE=InnoDB;

CREATE TABLE states (
  id          BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  country_id  BIGINT UNSIGNED NOT NULL,
  name        VARCHAR(100) NOT NULL,
  UNIQUE KEY uq_states_country_name (country_id, name),
  CONSTRAINT fk_states_country FOREIGN KEY (country_id) REFERENCES countries(id) ON DELETE RESTRICT
) ENGINE=InnoDB;

CREATE TABLE cities (
  id          BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  state_id    BIGINT UNSIGNED NOT NULL,
  name        VARCHAR(100) NOT NULL,
  UNIQUE KEY uq_cities_state_name (state_id, name),
  CONSTRAINT fk_cities_state FOREIGN KEY (state_id) REFERENCES states(id) ON DELETE RESTRICT
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- 2. IDENTITY & ACCESS
--    users = shared auth/account row for every role.
--    clients / teachers = one-to-one extension tables (class-table
--    inheritance) so role-specific columns are never nullable noise
--    on a row that belongs to a different role.
-- ---------------------------------------------------------------------

CREATE TABLE users (
  id            BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  email         VARCHAR(255) NOT NULL,
  phone         VARCHAR(20) NULL,
  password_hash VARCHAR(255) NOT NULL,
  role          ENUM('client','teacher','admin','subadmin') NOT NULL,
  status        ENUM('active','blocked') NOT NULL DEFAULT 'active',
  created_at    TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uq_users_email (email)
) ENGINE=InnoDB;

CREATE TABLE clients (
  user_id           BIGINT UNSIGNED PRIMARY KEY,
  full_name         VARCHAR(150) NOT NULL,
  gender            ENUM('female','male','other','undisclosed') NOT NULL DEFAULT 'undisclosed',
  city_id           BIGINT UNSIGNED NULL,
  pincode           VARCHAR(10) NULL,
  looking_for       VARCHAR(255) NULL COMMENT 'Free-text matching hint from the profile form',
  bio               TEXT NULL,
  profile_photo_url VARCHAR(500) NULL,
  CONSTRAINT fk_clients_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  CONSTRAINT fk_clients_city FOREIGN KEY (city_id) REFERENCES cities(id) ON DELETE SET NULL
) ENGINE=InnoDB;

CREATE TABLE teachers (
  user_id              BIGINT UNSIGNED PRIMARY KEY,
  full_name            VARCHAR(150) NOT NULL,
  gender               ENUM('female','male','other','undisclosed') NOT NULL DEFAULT 'undisclosed',
  years_experience     TINYINT UNSIGNED NOT NULL DEFAULT 0,
  teaching_mode        ENUM('online','offline','hybrid') NOT NULL DEFAULT 'hybrid',
  qualifications       TEXT NULL,
  bio                  TEXT NULL,
  profile_photo_url    VARCHAR(500) NULL,
  city_id              BIGINT UNSIGNED NULL,
  pincode              VARCHAR(10) NULL,
  per_session_price    DECIMAL(10,2) NULL,
  trial_price          DECIMAL(10,2) NULL,
  verification_status  ENUM('pending','verified','rejected') NOT NULL DEFAULT 'pending',
  team_rating          DECIMAL(2,1) NULL COMMENT 'Admin-assigned quality score (Teacher Directory). An independent input — blended with the *computed* AVG(ratings.stars) at query time to produce the public rating; the blended number itself is never stored.',
  CONSTRAINT fk_teachers_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  CONSTRAINT fk_teachers_city FOREIGN KEY (city_id) REFERENCES cities(id) ON DELETE SET NULL,
  CONSTRAINT chk_team_rating CHECK (team_rating IS NULL OR team_rating BETWEEN 1.0 AND 5.0)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- 3. TEACHER PROFILE — expertise, certifications, documents, extras
-- ---------------------------------------------------------------------

CREATE TABLE yoga_styles (
  id    BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  name  VARCHAR(100) NOT NULL,
  UNIQUE KEY uq_yoga_styles_name (name)
) ENGINE=InnoDB;

CREATE TABLE teacher_expertise (
  teacher_user_id BIGINT UNSIGNED NOT NULL,
  style_id        BIGINT UNSIGNED NOT NULL,
  PRIMARY KEY (teacher_user_id, style_id),
  CONSTRAINT fk_texp_teacher FOREIGN KEY (teacher_user_id) REFERENCES teachers(user_id) ON DELETE CASCADE,
  CONSTRAINT fk_texp_style   FOREIGN KEY (style_id)        REFERENCES yoga_styles(id)   ON DELETE RESTRICT
) ENGINE=InnoDB;

CREATE TABLE certification_types (
  id    BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  name  VARCHAR(150) NOT NULL,
  UNIQUE KEY uq_cert_types_name (name)
) ENGINE=InnoDB;

CREATE TABLE teacher_certifications (
  id                         BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  teacher_user_id            BIGINT UNSIGNED NOT NULL,
  certification_type_id      BIGINT UNSIGNED NULL,
  certification_name_other   VARCHAR(150) NULL COMMENT 'Used only when certification_type_id IS NULL (an "Other" entry)',
  issuing_body                VARCHAR(150) NULL,
  document_url                 VARCHAR(500) NULL,
  status                       ENUM('pending','verified','rejected') NOT NULL DEFAULT 'pending',
  verified_by                  BIGINT UNSIGNED NULL,
  verified_at                  TIMESTAMP NULL,
  CONSTRAINT fk_tcert_teacher  FOREIGN KEY (teacher_user_id)       REFERENCES teachers(user_id)          ON DELETE CASCADE,
  CONSTRAINT fk_tcert_type     FOREIGN KEY (certification_type_id) REFERENCES certification_types(id)    ON DELETE RESTRICT,
  CONSTRAINT fk_tcert_verifier FOREIGN KEY (verified_by)           REFERENCES users(id)                  ON DELETE SET NULL,
  CONSTRAINT chk_tcert_named   CHECK (certification_type_id IS NOT NULL OR certification_name_other IS NOT NULL)
) ENGINE=InnoDB;

CREATE TABLE teacher_documents (
  id              BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  teacher_user_id BIGINT UNSIGNED NOT NULL,
  doc_type        ENUM('aadhaar_front','aadhaar_back','government_id','liability_insurance','other') NOT NULL,
  file_url        VARCHAR(500) NULL,
  status          ENUM('pending','verified','missing') NOT NULL DEFAULT 'pending',
  uploaded_at     TIMESTAMP NULL,
  verified_by     BIGINT UNSIGNED NULL,
  verified_at     TIMESTAMP NULL,
  CONSTRAINT fk_tdoc_teacher  FOREIGN KEY (teacher_user_id) REFERENCES teachers(user_id) ON DELETE CASCADE,
  CONSTRAINT fk_tdoc_verifier FOREIGN KEY (verified_by)     REFERENCES users(id)         ON DELETE SET NULL
) ENGINE=InnoDB;

CREATE TABLE teacher_online_locations (
  id              BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  teacher_user_id BIGINT UNSIGNED NOT NULL,
  location_label  VARCHAR(150) NOT NULL,
  CONSTRAINT fk_tloc_teacher FOREIGN KEY (teacher_user_id) REFERENCES teachers(user_id) ON DELETE CASCADE,
  UNIQUE KEY uq_tloc_teacher_label (teacher_user_id, location_label)
) ENGINE=InnoDB;

CREATE TABLE teacher_pricing_packages (
  id              BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  teacher_user_id BIGINT UNSIGNED NOT NULL,
  session_count   SMALLINT UNSIGNED NOT NULL,
  total_price     DECIMAL(10,2) NOT NULL,
  CONSTRAINT fk_tpkg_teacher FOREIGN KEY (teacher_user_id) REFERENCES teachers(user_id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- 4. REQUIREMENTS (job board postings) & APPLICATIONS
-- ---------------------------------------------------------------------

CREATE TABLE requirements (
  id                          BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  client_user_id              BIGINT UNSIGNED NOT NULL,
  title                       VARCHAR(200) NOT NULL,
  style_id                    BIGINT UNSIGNED NULL,
  purpose                     ENUM('personal_practice','therapeutic','prenatal','corporate_wellness','group_class','certification_prep','other') NOT NULL DEFAULT 'personal_practice',
  certification_required_id   BIGINT UNSIGNED NULL,
  preferred_gender            ENUM('no_preference','female','male','other') NOT NULL DEFAULT 'no_preference',
  mode                        ENUM('online','offline','either') NOT NULL DEFAULT 'either',
  demo_class_time             DATETIME NULL,
  city_id                     BIGINT UNSIGNED NULL,
  pincode                     VARCHAR(10) NULL,
  area                        VARCHAR(150) NULL,
  budget_min                  DECIMAL(10,2) NULL,
  budget_max                  DECIMAL(10,2) NULL,
  description                 TEXT NULL,
  status                      ENUM('open','matched','closed') NOT NULL DEFAULT 'open',
  is_visible                  TINYINT(1) NOT NULL DEFAULT 1 COMMENT 'Admin block toggle — pulls it off the public job board without deleting it',
  source                      ENUM('platform','phone_call','whatsapp','walk_in','referral') NOT NULL DEFAULT 'platform',
  posted_by_admin_id          BIGINT UNSIGNED NULL COMMENT 'Set when an admin used "Post for a Client"',
  created_at                  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_req_client FOREIGN KEY (client_user_id)            REFERENCES clients(user_id)          ON DELETE CASCADE,
  CONSTRAINT fk_req_style  FOREIGN KEY (style_id)                  REFERENCES yoga_styles(id)           ON DELETE SET NULL,
  CONSTRAINT fk_req_cert   FOREIGN KEY (certification_required_id) REFERENCES certification_types(id)   ON DELETE SET NULL,
  CONSTRAINT fk_req_city   FOREIGN KEY (city_id)                   REFERENCES cities(id)                ON DELETE SET NULL,
  CONSTRAINT fk_req_admin  FOREIGN KEY (posted_by_admin_id)        REFERENCES users(id)                 ON DELETE SET NULL,
  CONSTRAINT chk_req_budget CHECK (budget_min IS NULL OR budget_max IS NULL OR budget_min <= budget_max)
) ENGINE=InnoDB;

CREATE TABLE requirement_availability_slots (
  id             BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  requirement_id BIGINT UNSIGNED NOT NULL,
  slot_label     VARCHAR(50) NOT NULL COMMENT 'e.g. "Morning (7-10am)"',
  CONSTRAINT fk_reqslot_req FOREIGN KEY (requirement_id) REFERENCES requirements(id) ON DELETE CASCADE,
  UNIQUE KEY uq_reqslot (requirement_id, slot_label)
) ENGINE=InnoDB;

CREATE TABLE requirement_applications (
  id              BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  requirement_id  BIGINT UNSIGNED NOT NULL,
  teacher_user_id BIGINT UNSIGNED NOT NULL,
  status          ENUM('pending','approved','rejected') NOT NULL DEFAULT 'pending',
  applied_at      TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  decided_at      TIMESTAMP NULL,
  CONSTRAINT fk_reqapp_req     FOREIGN KEY (requirement_id)  REFERENCES requirements(id)  ON DELETE CASCADE,
  CONSTRAINT fk_reqapp_teacher FOREIGN KEY (teacher_user_id) REFERENCES teachers(user_id) ON DELETE CASCADE,
  UNIQUE KEY uq_reqapp (requirement_id, teacher_user_id)
) ENGINE=InnoDB;
-- Per-requirement applicant count ("2 teachers applied") = COUNT(*) here — never cached on requirements.

-- ---------------------------------------------------------------------
-- 5. CONNECTIONS, AVAILABILITY BOOKING, MESSAGES, RATINGS
--    `connections` is the single canonical "we are now in touch" edge,
--    regardless of whether it started as a direct browse-and-request
--    or an approved job application — both dashboards read this one
--    table instead of maintaining two parallel contact-exchange models.
-- ---------------------------------------------------------------------

CREATE TABLE connections (
  id                     BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  client_user_id         BIGINT UNSIGNED NOT NULL,
  teacher_user_id        BIGINT UNSIGNED NOT NULL,
  origin                 ENUM('direct_browse','requirement_application') NOT NULL DEFAULT 'direct_browse',
  source_application_id  BIGINT UNSIGNED NULL COMMENT 'Set when origin = requirement_application',
  status                 ENUM('pending','approved','declined') NOT NULL DEFAULT 'pending',
  decline_reason         VARCHAR(500) NULL,
  fee_charged            DECIMAL(10,2) NULL COMMENT 'NULL while the platform fee is OFF, or on a free first connection',
  requested_at           TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  decided_at             TIMESTAMP NULL,
  whatsapp_shared_at     TIMESTAMP NULL,
  CONSTRAINT fk_conn_client      FOREIGN KEY (client_user_id)        REFERENCES clients(user_id)               ON DELETE CASCADE,
  CONSTRAINT fk_conn_teacher     FOREIGN KEY (teacher_user_id)       REFERENCES teachers(user_id)              ON DELETE CASCADE,
  CONSTRAINT fk_conn_application FOREIGN KEY (source_application_id) REFERENCES requirement_applications(id)   ON DELETE SET NULL,
  UNIQUE KEY uq_conn_client_teacher (client_user_id, teacher_user_id)
) ENGINE=InnoDB;

CREATE TABLE teacher_weekly_availability (
  id                    BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  teacher_user_id       BIGINT UNSIGNED NOT NULL,
  day_of_week           TINYINT UNSIGNED NOT NULL COMMENT '1=Mon ... 7=Sun',
  time_slot             VARCHAR(20) NOT NULL COMMENT 'e.g. "07:00"',
  is_available          TINYINT(1) NOT NULL DEFAULT 0,
  booked_connection_id  BIGINT UNSIGNED NULL COMMENT 'Which approved connection currently occupies this recurring slot, if any — this is "slot filled" made queryable instead of a plain summary count.',
  CONSTRAINT fk_avail_teacher    FOREIGN KEY (teacher_user_id)      REFERENCES teachers(user_id)  ON DELETE CASCADE,
  CONSTRAINT fk_avail_connection FOREIGN KEY (booked_connection_id) REFERENCES connections(id)    ON DELETE SET NULL,
  UNIQUE KEY uq_avail_slot (teacher_user_id, day_of_week, time_slot)
  -- booked_connection_id => is_available=1 is enforced at the application layer:
  -- MySQL rejects a CHECK on a column that's also the target of an ON DELETE/UPDATE
  -- SET NULL foreign key action (ER_CHECK_CONSTRAINT_CLAUSE_USING_FK_REFER_ACTION_COLUMN).
) ENGINE=InnoDB;

CREATE TABLE messages (
  id             BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  connection_id  BIGINT UNSIGNED NOT NULL,
  sender_user_id BIGINT UNSIGNED NOT NULL,
  body           TEXT NOT NULL,
  sent_at        TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_msg_connection FOREIGN KEY (connection_id)  REFERENCES connections(id) ON DELETE CASCADE,
  CONSTRAINT fk_msg_sender     FOREIGN KEY (sender_user_id) REFERENCES users(id)       ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE ratings (
  id              BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  connection_id   BIGINT UNSIGNED NOT NULL,
  teacher_user_id BIGINT UNSIGNED NOT NULL,
  client_user_id  BIGINT UNSIGNED NOT NULL,
  stars           TINYINT UNSIGNED NOT NULL,
  review_text     TEXT NULL,
  status          ENUM('published','flagged','removed') NOT NULL DEFAULT 'published',
  flagged_reason  VARCHAR(500) NULL,
  created_at      TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_rating_connection FOREIGN KEY (connection_id)   REFERENCES connections(id) ON DELETE CASCADE,
  CONSTRAINT fk_rating_teacher    FOREIGN KEY (teacher_user_id) REFERENCES teachers(user_id) ON DELETE CASCADE,
  CONSTRAINT fk_rating_client     FOREIGN KEY (client_user_id)  REFERENCES clients(user_id)  ON DELETE CASCADE,
  UNIQUE KEY uq_rating_connection (connection_id) COMMENT 'One rating per connection — matches the site (Rate this teacher appears once per approved connection)',
  CONSTRAINT chk_rating_stars CHECK (stars BETWEEN 1 AND 5)
) ENGINE=InnoDB;
-- A teacher's public "student rating" = AVG(stars) WHERE teacher_user_id=? AND status='published' — computed, not stored.
-- Public blended rating = (student_avg * 0.7) + (teachers.team_rating * 0.3), computed at read time.

-- ---------------------------------------------------------------------
-- 6. WALLET — a ledger, not a mutable balance column
-- ---------------------------------------------------------------------

CREATE TABLE wallet_transactions (
  id           BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  user_id      BIGINT UNSIGNED NOT NULL,
  credit_type  ENUM('free_requirement_posting','free_connection','job_application_credit','profile_completion_bonus') NOT NULL,
  delta_amount SMALLINT NOT NULL COMMENT 'Positive = granted, negative = spent',
  reason       VARCHAR(255) NULL,
  created_at   TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_wallet_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB;
-- Any balance ("2 of 3 job-application credits remaining") = SUM(delta_amount)
-- WHERE user_id=? AND credit_type=? — a mutable stored balance would be a
-- second source of truth that could drift from this history; not used here.

-- ---------------------------------------------------------------------
-- 7. PLATFORM ADMINISTRATION
-- ---------------------------------------------------------------------

CREATE TABLE platform_settings (
  setting_key   VARCHAR(100) PRIMARY KEY,
  setting_value VARCHAR(500) NOT NULL,
  updated_by    BIGINT UNSIGNED NULL,
  updated_at    TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT fk_settings_user FOREIGN KEY (updated_by) REFERENCES users(id) ON DELETE SET NULL
) ENGINE=InnoDB;
-- Rows: platform_fee_enabled, platform_fee_amount, first_connection_free_rule, pricing_visible_platform_wide.

CREATE TABLE cms_content_blocks (
  id             BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  block_key      VARCHAR(100) NOT NULL,
  label          VARCHAR(200) NOT NULL,
  content        TEXT NOT NULL,
  last_edited_by BIGINT UNSIGNED NULL,
  last_edited_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  UNIQUE KEY uq_cms_key (block_key),
  CONSTRAINT fk_cms_user FOREIGN KEY (last_edited_by) REFERENCES users(id) ON DELETE SET NULL
) ENGINE=InnoDB;

CREATE TABLE permission_modules (
  id           BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  module_key   VARCHAR(50) NOT NULL,
  module_label VARCHAR(100) NOT NULL,
  UNIQUE KEY uq_perm_module_key (module_key)
) ENGINE=InnoDB;
-- Rows: verification, teacher_client_accounts, pricing_fees, ratings, cms.

CREATE TABLE subadmin_permissions (
  subadmin_user_id BIGINT UNSIGNED NOT NULL,
  module_id        BIGINT UNSIGNED NOT NULL,
  granted_by        BIGINT UNSIGNED NULL,
  granted_at         TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (subadmin_user_id, module_id),
  CONSTRAINT fk_subperm_user    FOREIGN KEY (subadmin_user_id) REFERENCES users(id)              ON DELETE CASCADE,
  CONSTRAINT fk_subperm_module  FOREIGN KEY (module_id)        REFERENCES permission_modules(id)  ON DELETE CASCADE,
  CONSTRAINT fk_subperm_granter FOREIGN KEY (granted_by)       REFERENCES users(id)               ON DELETE SET NULL
) ENGINE=InnoDB;
-- The permissions-matrix checkboxes in the Admin dashboard are literally
-- "does a row exist here for (subadmin, module)" — no boolean grid column.

CREATE TABLE audit_logs (
  id            BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  actor_user_id BIGINT UNSIGNED NULL COMMENT 'NULL for system-generated events',
  action        VARCHAR(255) NOT NULL,
  target_type   VARCHAR(50) NULL,
  target_id     BIGINT UNSIGNED NULL,
  created_at    TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_audit_actor FOREIGN KEY (actor_user_id) REFERENCES users(id) ON DELETE SET NULL
) ENGINE=InnoDB;
-- Catches heterogeneous one-off events only (logged in, changed pricing,
-- updated availability). The admin's "Connection Logs" and "Client &
-- Requirement Logs" screens are NOT separate tables — they're just
-- SELECTs over `connections` and `requirements`, which already carry
-- status + timestamps. Duplicating that into a second logging table
-- would be the exact kind of redundant, driftable copy this schema
-- avoids everywhere else.

-- ---------------------------------------------------------------------
-- 8. SUPPORTING INDEXES (beyond the ones MySQL creates automatically
--    for FK and UNIQUE columns) — for the filters every dashboard uses.
-- ---------------------------------------------------------------------

CREATE INDEX idx_requirements_status   ON requirements(status);
CREATE INDEX idx_requirements_visible  ON requirements(is_visible);
CREATE INDEX idx_reqapp_status         ON requirement_applications(status);
CREATE INDEX idx_connections_status    ON connections(status);
CREATE INDEX idx_ratings_status        ON ratings(status);
CREATE INDEX idx_teachers_verification ON teachers(verification_status);
CREATE INDEX idx_users_role_status     ON users(role, status);

SET FOREIGN_KEY_CHECKS = 1;
