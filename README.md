# Shunya Mindstream

This is a monorepo containing:
- `backend/`: Python + FastAPI application with Poetry.

## Getting Started

### Backend
1. Navigate to the backend directory:
   ```bash
   cd backend
   ```
2. Install dependencies via poetry (make sure Poetry is installed):
   ```bash
   poetry install
   ```
3. Run the FastAPI development server:
   ```bash
   poetry run uvicorn main:app --reload
   ```
