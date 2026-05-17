# BancApp Employee Dashboard

A three-tier containerized application featuring a Flask REST API, Nginx frontend, and PostgreSQL database — deployed with Docker Compose, CI/CD via GitHub Actions, image-based rollback, and automated hourly monitoring.

---

## Architecture

```
Browser
  │
  ▼
┌──────────────────────────────┐
│  Frontend (Nginx : 80)       │  http://server-ip/
│  Serves static HTML          │
│  Proxies /api/ → backend     │
└──────────────┬───────────────┘
               │ internal network
               ▼
┌──────────────────────────────┐
│  Backend (Flask : 5000)      │  http://server-ip/api/
│  REST CRUD API               │
└──────────────┬───────────────┘
               │ internal network
               ▼
┌──────────────────────────────┐
│  Database (PostgreSQL)       │  Internal only
│  Persistent volume           │
└──────────────────────────────┘
```

| Service  | URL                    | Technology       |
|----------|------------------------|------------------|
| Frontend | `http://server-ip/`    | Nginx + HTML/JS  |
| Backend  | `http://server-ip/api` | Python Flask     |
| Database | Internal only          | PostgreSQL 15    |

---

## Project Structure

```
Employee_Dashboard/
├── frontend/
│   ├── Dockerfile
│   ├── index.html
│   └── nginx.conf
├── backend/
│   ├── Dockerfile
│   ├── app.py
│   └── requirements.txt
├── monitoring/
│   ├── monitor.sh        # Metrics collection script
│   └── setup-cron.sh     # Cron installer
├── scripts/
│   └── rollback.sh       # Image-based rollback
├── .github/
│   └── workflows/
│       └── ci-cd.yml     # GitHub Actions pipeline
├── docker-compose.yml
├── .env.example
└── README.md
```

---

## Setup Instructions

### Prerequisites

- Docker >= 24.x
- Docker Compose >= 2.x
- Git

### 1. Clone the Repository

```bash
git clone https://github.com/<your-username>/Employee_Dashboard.git
cd Employee_Dashboard
```

### 2. Configure Environment Variables

```bash
cp .env.example .env
# Edit .env and set your own POSTGRES_PASSWORD
```

### 3. Start the Application

```bash
docker compose up -d --build
```

### 4. Verify Services

```bash
# Check all containers are healthy
docker compose ps

# Test frontend
curl http://localhost/

# Test API
curl http://localhost/api/
# Expected: {"message": "Hello from API"}

# Test employees endpoint
curl http://localhost/api/employees
```

### 5. Stop the Application

```bash
docker compose down          # Stop only
docker compose down -v       # Stop + remove volumes (deletes DB data)
```

---

## API Endpoints

| Method | Endpoint               | Description         |
|--------|------------------------|---------------------|
| GET    | `/api/`                | Health / API info   |
| GET    | `/api/employees`       | List all employees  |
| POST   | `/api/employees`       | Add new employee    |
| PUT    | `/api/employees/<id>`  | Update employee     |
| DELETE | `/api/employees/<id>`  | Delete employee     |

**POST / PUT body example:**
```json
{
  "name": "Alice",
  "department": "Engineering"
}
```

---

## CI/CD Pipeline

The pipeline is defined in `.github/workflows/ci-cd.yml` and triggers on every `git push` to `main`.

### Pipeline Steps

| Step | Action |
|------|--------|
| 1 | Checkout repository |
| 2 | Set image tag = `git commit hash (8 chars)` |
| 3 | Login to Docker Hub |
| 4 | Build frontend & backend Docker images |
| 5 | Push images tagged with commit hash **and** `latest` |
| 6 | Start application stack for smoke testing |
| 7 | Run smoke tests (HTTP 200 on `/`, valid JSON on `/api/`) |
| 8 | If tests **fail** → auto rollback to previous image |
| 9 | If tests **pass** → deploy to production |

### Required GitHub Secrets

Go to `Settings → Secrets and variables → Actions` and add:

| Secret Name          | Value                      |
|----------------------|----------------------------|
| `DOCKER_HUB_USERNAME` | Your Docker Hub username  |
| `DOCKER_HUB_TOKEN`   | Your Docker Hub access token |

---

## Rollback Instructions

Rollback is **image-based** (not git revert). The last 2 image versions are kept in Docker Hub.

### Automatic Rollback

If smoke tests fail in the CI/CD pipeline, `scripts/rollback.sh` is called automatically.

### Manual Rollback

**Option 1 — Roll back to the previous version automatically:**
```bash
export DOCKER_HUB_USERNAME=your_dockerhub_username
bash scripts/rollback.sh
```
The script fetches the last 5 tags from Docker Hub, picks the second most recent (previous), and redeploys.

**Option 2 — Roll back to a specific commit hash:**
```bash
export DOCKER_HUB_USERNAME=your_dockerhub_username
bash scripts/rollback.sh a1b2c3d4
```

**What the rollback script does:**
1. Pulls the specified (or auto-detected previous) image tag from Docker Hub
2. Re-tags those images as `latest`
3. Runs `docker compose down && docker compose up -d`

---

## Monitoring

### What is Monitored

| Metric               | Source                          |
|----------------------|---------------------------------|
| Server CPU usage     | `top` command                   |
| Server RAM usage     | `free -h`                       |
| Disk (ROM) usage     | `df -h`                         |
| Container status     | `docker ps -a`                  |
| Per-container CPU/RAM| `docker stats --no-stream`      |
| API response time    | `curl` with timing output       |

### Report Location

Reports are saved to `/var/log/app-monitor/report_<timestamp>.log`

The last **48 reports** are kept (48 hours of history). Older reports are deleted automatically.

### Setup Cron Job

Run once on your server after deployment:

```bash
sudo bash monitoring/setup-cron.sh
```

This installs the cron job:
```
0 * * * * /bin/bash /path/to/monitoring/monitor.sh
```

### Run Manually

```bash
bash monitoring/monitor.sh
```

### View Reports

```bash
# Latest report
ls -lt /var/log/app-monitor/ | head -5

# Read a report
cat /var/log/app-monitor/report_2025-01-01_10-00-00.log
```

### Sample Report Output

```
============================================
  SYSTEM MONITORING REPORT
  Generated: 2025-01-01 10:00:00
============================================

[ SERVER CPU USAGE ]
  CPU Used: 12.5%
  CPU Idle: 87.5%

[ SERVER RAM USAGE ]
  Total RAM : 7.7G
  Used  RAM : 1.2G
  Free  RAM : 5.3G

[ DISK (ROM) USAGE ]
  /dev/sda1   50G  8.2G   42G  17% /

[ CONTAINER STATUS ]
  Name: employee_dashboard-frontend-1 | Status: Up 2 hours | Image: employee-frontend:latest
  Name: employee_dashboard-backend-1  | Status: Up 2 hours | Image: employee-backend:latest
  Name: employee_dashboard-db-1       | Status: Up 2 hours | Image: postgres:15

[ PER-CONTAINER CPU & RAM ]
  employee_dashboard-frontend-1 | CPU: 0.01% | RAM: 5.2MiB / 7.7GiB (0.07%)
  employee_dashboard-backend-1  | CPU: 0.12% | RAM: 42MiB / 7.7GiB (0.53%)
  employee_dashboard-db-1       | CPU: 0.05% | RAM: 38MiB / 7.7GiB (0.48%)

[ API RESPONSE TIME ]
  HTTP Status : 200
  Total Time  : 0.045s
  Connect Time: 0.001s

============================================
  END OF REPORT
============================================
```

---

## Screenshots

> Add your screenshots here after running the project.

- `screenshots/pipeline.png` — Successful GitHub Actions run
- `screenshots/Monitoring_Script.png` — Sample monitoring output
- `screenshots/Frontend.png` — Frontend at http://server-ip/
- `screenshots/API.png` — API at http://server-ip/api/

---

## Troubleshooting

**Containers not starting:**
```bash
docker compose logs frontend
docker compose logs backend
docker compose logs db
```

**Database connection errors:**
```bash
# Check DB is healthy
docker compose ps db
# Restart backend after DB is ready
docker compose restart backend
```

**Port 80 already in use:**
```bash
sudo lsof -i :80
# Change frontend port in docker-compose.yml if needed
```

