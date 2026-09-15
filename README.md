# YogSetu / GrowYogi

Marketing site + backend for GrowYogi — helping yoga teachers and studios grow digitally.

## Stack

- **Backend:** Node.js + Express
- **Frontend:** Static HTML/CSS/JS with Bootstrap 5 + jQuery (served from `public/`)
- **Database:** MySQL 8.4

## Project structure

```
yogsetu/
├── app.js                 # Express entry point
├── config/db.js           # MySQL connection pool (mysql2)
├── routes/api.js          # JSON API routes (/api/leads, /api/contact)
├── database/schema.sql    # DB schema
├── public/                # Static site — served as-is
│   ├── index.html         # Homepage (GrowYogi landing page)
│   ├── jobs.html, teacher-login.html, yoga-teachers.html, ...
│   ├── images/
│   ├── css/, js/
└── .env                   # Local config (not committed)
```

## Setup

1. Install dependencies:
   ```
   npm install
   ```
2. Copy `.env.example` to `.env` and fill in your MySQL credentials.
3. Create the database and apply the schema:
   ```
   mysql -u root -p -e "CREATE DATABASE yogsetu CHARACTER SET utf8mb4;"
   mysql -u root -p yogsetu < database/schema.sql
   ```
4. Run the server:
   ```
   npm run dev     # with nodemon (auto-restart)
   npm start        # plain node
   ```
5. Visit http://localhost:3000

## API

- `POST /api/leads` — homepage "Free Growth Plan" form. Body: `{ name, whatsapp, city, role, plan }`.
- `POST /api/contact` — generic contact/enquiry submissions. Body: `{ name, email, phone, message, source_page }`.

## Database tables

- `leads` — homepage lead-capture form submissions
- `contact_messages` — generic enquiries (jobs, teacher signup, etc.)
- `teachers` — scaffolded for `teacher-login.html` once auth is wired up
- `jobs` — scaffolded for `jobs.html` / job detail pages once wired up

## Notes

- The static pages (`jobs.html`, `yoga-teachers.html`, `teacher-login.html`, etc.) are currently served as-is and are not yet backed by the `teachers`/`jobs` tables — only the homepage lead form is wired to MySQL so far.
- MySQL is currently running as a plain background process, not a Windows service. To install it as a service (auto-start on boot), run this **in an elevated (Run as Administrator) PowerShell**:
  ```
  & "C:\Program Files\MySQL\MySQL Server 8.4\bin\mysqld.exe" --install MySQL84 --defaults-file="C:\ProgramData\MySQL\MySQL Server 8.4\my.ini"
  Start-Service MySQL84
  ```
