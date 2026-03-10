# phunzira Backend API

School Management System Backend API built with Node.js, Express, and PostgreSQL (Neon).

## Features

- 🔐 JWT Authentication with Refresh Tokens
- 📧 Email Verification
- 🔑 Password Reset Flow
- 👤 User Profile Management
- 🛡️ Role-based Access Control (User/Admin)
- 📊 Audit Logging
- 📱 Session Management
- 🚀 Rate Limiting
- ✅ Input Validation
- 📝 Request Logging
- 🔒 Security Headers (Helmet)

## Tech Stack

- Node.js
- Express
- PostgreSQL (Neon)
- JSON Web Tokens
- Bcrypt
- Express Validator
- Helmet
- CORS
- Rate Limiting

## API Endpoints

### Authentication
- `POST /api/auth/register` - Register new user
- `POST /api/auth/login` - Login user
- `POST /api/auth/refresh-token` - Refresh access token
- `POST /api/auth/logout` - Logout user
- `POST /api/auth/logout-all` - Logout from all devices
- `POST /api/auth/change-password` - Change password
- `POST /api/auth/forgot-password` - Request password reset
- `POST /api/auth/reset-password` - Reset password with token
- `GET /api/auth/verify-email/:token` - Verify email

### Users
- `GET /api/users/profile` - Get user profile
- `PUT /api/users/profile` - Update profile
- `POST /api/users/profile/picture` - Upload profile picture
- `GET /api/users/sessions` - Get active sessions
- `DELETE /api/users/sessions/:id` - Revoke session

### Admin
- `GET /api/users/admin/users` - Get all users
- `GET /api/users/admin/users/:id` - Get user by ID
- `PUT /api/users/admin/users/:id/deactivate` - Deactivate user
- `PUT /api/users/admin/users/:id/activate` - Activate user
- `DELETE /api/users/admin/users/:id` - Delete user

## Installation

1. Clone repository
2. Install dependencies:
   ```bash
   npm install