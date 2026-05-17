# Shunya Mindstream

This is a monorepo containing:
- `frontend/`: React + TypeScript + Vite application.
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

### Frontend
1. Navigate to the frontend directory:
   ```bash
   cd frontend
   ```
2. Install dependencies:
   ```bash
   npm install
   ```
3. Run the Vite development server:
   ```bash
   npm run dev
   ```
