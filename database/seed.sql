-- Minimal reference data so signup/requirement forms have real IDs to point at.
-- Run after schema.sql.

INSERT INTO yoga_styles (name) VALUES
  ('Hatha Yoga'), ('Ashtanga / Power'), ('Prenatal Yoga'), ('Therapeutic Yoga'),
  ('Meditation'), ('Yoga of Education'), ('Corporate Wellness'), ('Yoga for Seniors');

INSERT INTO countries (name) VALUES ('India');

INSERT INTO states (country_id, name)
SELECT id, 'Uttar Pradesh' FROM countries WHERE name = 'India'
UNION ALL SELECT id, 'Delhi' FROM countries WHERE name = 'India'
UNION ALL SELECT id, 'Karnataka' FROM countries WHERE name = 'India'
UNION ALL SELECT id, 'Maharashtra' FROM countries WHERE name = 'India'
UNION ALL SELECT id, 'Haryana' FROM countries WHERE name = 'India';

INSERT INTO cities (state_id, name)
SELECT id, 'Lucknow' FROM states WHERE name = 'Uttar Pradesh'
UNION ALL SELECT id, 'Kanpur' FROM states WHERE name = 'Uttar Pradesh'
UNION ALL SELECT id, 'New Delhi' FROM states WHERE name = 'Delhi'
UNION ALL SELECT id, 'Bengaluru' FROM states WHERE name = 'Karnataka'
UNION ALL SELECT id, 'Mumbai' FROM states WHERE name = 'Maharashtra'
UNION ALL SELECT id, 'Pune' FROM states WHERE name = 'Maharashtra'
UNION ALL SELECT id, 'Gurugram' FROM states WHERE name = 'Haryana';

INSERT INTO certification_types (name) VALUES
  ('RYT 200'), ('RYT 500'), ('Yoga Alliance Certified'), ('Diploma in Yoga Science'), ('Other');

INSERT INTO permission_modules (module_key, module_label) VALUES
  ('verification', 'Teacher Verification'),
  ('teacher_client_accounts', 'Teacher & Client Accounts'),
  ('pricing_fees', 'Pricing & Fees'),
  ('ratings', 'Ratings & Reviews'),
  ('cms', 'CMS Content');

INSERT INTO platform_settings (setting_key, setting_value) VALUES
  ('platform_fee_enabled', 'false'),
  ('platform_fee_amount', '0'),
  ('first_connection_free_rule', 'true'),
  ('pricing_visible_platform_wide', 'true');
