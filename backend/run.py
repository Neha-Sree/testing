#!/usr/bin/env python3
"""
Entry point for the FastAPI application.
Run this script to start the backend server.
"""

import sys
import os

# Add the current directory to Python path so imports work
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from app import env as _env  # noqa: F401 — load backend/.env before app imports

from app.main import app

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("app.main:app", host="0.0.0.0", port=8000, reload=True)
