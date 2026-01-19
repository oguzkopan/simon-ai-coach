# Simon Backend API

Go backend service for the Simon AI Coach app, deployed on Google Cloud Run.

## Project Information

- **Project ID**: simon-7a833
- **Project Number**: 84366855987
- **Region**: us-central1

## Quick Start

### Local Development

```bash
cd backend
./run-local.sh
```

This will:
1. Set up authentication with Google Cloud
2. Download dependencies
3. Start the server on http://localhost:8080

### Deploy to Production

```bash
cd backend
./deploy.sh
```

This will:
1. Build the Docker container
2. Push to Google Container Registry
3. Deploy to Cloud Run with cost-optimized settings
4. Output the production URL

## Cost Optimization

The deployment is configured for minimum costs:

- **Memory**: 256Mi (minimum allowed)
- **CPU**: 1 (minimum)
- **Min instances**: 0 (scales to zero when not in use)
- **Max instances**: 10
- **CPU throttling**: Enabled
- **CPU boost**: Disabled
- **Execution environment**: gen2 (more efficient)

**Expected costs**: ~$0-5/month for low traffic (scales to zero when idle)

## API Endpoints

### Public
- `GET /healthz` - Health check

### Protected (requires Firebase auth)
- `GET /v1/me` - User profile
- `GET /v1/coaches` - List coaches
- `POST /v1/coaches` - Create coach
- `GET /v1/sessions` - List sessions
- `POST /v1/sessions` - Create session
- `POST /v1/sessions/:id/messages` - Send message
- `GET /v1/sessions/:id/stream` - Stream chat (SSE)
- `GET /v1/systems` - List systems
- `POST /v1/systems` - Create system
- `POST /v1/moments` - Create moment

## Environment Variables

See `.env.example` for all configuration options. Key variables:

- `GCP_PROJECT`: simon-7a833
- `GCP_LOCATION`: us-central1
- `GEMINI_MODEL_ID`: gemini-2.0-flash-exp
- `PORT`: 8080

## Architecture

```
backend/
├── cmd/api/main.go           # Entry point
├── internal/
│   ├── config/               # Configuration
│   ├── firestore/            # Firestore client
│   ├── gemini/               # Gemini AI client
│   ├── agent/                # AI agent logic
│   ├── http/                 # HTTP handlers & middleware
│   ├── sse/                  # Server-sent events
│   └── logger/               # Logging
├── scripts/                  # Utility scripts
├── deploy.sh                 # Production deployment
├── run-local.sh             # Local development
└── Dockerfile               # Container definition
```

## Testing

```bash
# Health check
curl http://localhost:8080/healthz

# With authentication (get token from iOS app)
curl -H "Authorization: Bearer YOUR_TOKEN" \
  http://localhost:8080/v1/me
```

## Monitoring

View logs in Google Cloud Console:
```bash
gcloud logs tail --project=simon-7a833
```

## Troubleshooting

### Authentication Issues
```bash
gcloud auth application-default login
gcloud config set project simon-7a833
```

### Port Already in Use
```bash
lsof -i :8080
kill -9 <PID>
```

### Deployment Fails
- Ensure billing is enabled on the project
- Check that all required APIs are enabled
- Verify you have necessary permissions

## Support

For issues or questions, check the documentation in `/backend/BACKEND_SETUP.md`
