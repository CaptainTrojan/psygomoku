# Psygomoku Backend

Cloudflare Workers + Durable Objects signaling server for WebRTC P2P connections.

## Architecture

- **Worker** (`src/index.js`): HTTP/WebSocket router + static asset serving
- **Durable Object** (`src/room.js`): Stateful signaling room per session code
- **Workers Sites**: Serves Flutter web build from same Worker

## Development

```bash
# Install dependencies
npm install

# Run local dev server
npm run dev

# Deploy to Cloudflare
npm run deploy
```

## API

### POST /api/session
Create a new 4-digit session code.

**Response:**
```json
{
  "sessionCode": "1234"
}
```

### GET /ws/:roomCode
Upgrade to WebSocket for signaling. Room code must be 4 digits.

**Messages:**
- `{"type": "ROLE_ASSIGNED", "role": "host"|"joiner"}` - Server assigns role
- `{"type": "OFFER", "sdp": "..."}` - Relay SDP offer
- `{"type": "ANSWER", "sdp": "..."}` - Relay SDP answer
- `{"type": "ICE_CANDIDATE", "candidate": {...}}` - Relay ICE candidate
- `{"type": "PEER_DISCONNECTED", "role": "..."}` - Peer left

## Configuration

Edit `wrangler.toml`:
- `name`: Worker name
- `kv_namespaces.id`: Production KV namespace ID (after first deploy)
- `site.bucket`: Path to Flutter web build output (default: `../build/web`)

## Rate Limiting

- Session creation: 10 requests/hour per IP
- Enforced via KV storage with automatic expiration
