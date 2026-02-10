/**
 * Psygomoku Worker - Main entry point
 * 
 * Routes:
 * - POST /api/session - Create new session code
 * - GET /ws/:roomCode - WebSocket upgrade for signaling
 * - GET /* - Serve static Flutter web assets
 */

import { getAssetFromKV } from '@cloudflare/kv-asset-handler';

export { SignalingRoom } from './room.js';

/**
 * Rate limiting using KV
 */
class RateLimiter {
  constructor(kv, maxRequests = 10, windowMs = 3600000) {
    this.kv = kv;
    this.maxRequests = maxRequests;
    this.windowMs = windowMs;
  }

  async check(ip) {
    const key = `ratelimit:${ip}`;
    const now = Date.now();
    
    try {
      const data = await this.kv.get(key, 'json');
      
      if (!data) {
        // First request
        await this.kv.put(key, JSON.stringify({
          count: 1,
          resetAt: now + this.windowMs
        }), {
          expirationTtl: Math.floor(this.windowMs / 1000)
        });
        return true;
      }

      if (now > data.resetAt) {
        // Window expired, reset
        await this.kv.put(key, JSON.stringify({
          count: 1,
          resetAt: now + this.windowMs
        }), {
          expirationTtl: Math.floor(this.windowMs / 1000)
        });
        return true;
      }

      if (data.count >= this.maxRequests) {
        return false;
      }

      // Increment counter
      await this.kv.put(key, JSON.stringify({
        count: data.count + 1,
        resetAt: data.resetAt
      }), {
        expirationTtl: Math.floor((data.resetAt - now) / 1000)
      });
      return true;
    } catch (error) {
      console.error('Rate limit check error:', error);
      return true; // Fail open
    }
  }
}

/**
 * Generate random 4-digit session code
 */
function generateSessionCode() {
  return Math.floor(1000 + Math.random() * 9000).toString();
}

/**
 * Get client IP address
 */
function getClientIP(request) {
  return request.headers.get('CF-Connecting-IP') || 
         request.headers.get('X-Forwarded-For')?.split(',')[0] || 
         'unknown';
}

export default {
  async fetch(request, env, ctx) {
    const url = new URL(request.url);
    const path = url.pathname;

    // CORS headers - allow same origin (production) or localhost (development)
    const origin = request.headers.get('Origin');
    const requestHost = url.host;
    let allowedOrigin = '*';
    
    if (origin) {
      const originUrl = new URL(origin);
      // Allow if same host (production) or localhost dev (different ports)
      if (originUrl.host === requestHost || originUrl.hostname === 'localhost' || originUrl.hostname === '127.0.0.1') {
        allowedOrigin = origin;
      }
    }

    const corsHeaders = {
      'Access-Control-Allow-Origin': allowedOrigin,
      'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type',
    };

    // Handle CORS preflight
    if (request.method === 'OPTIONS') {
      return new Response(null, { headers: corsHeaders });
    }

    try {
      // Route: Create new session
      if (path === '/api/session' && request.method === 'POST') {
        const sessionCode = generateSessionCode();
        
        return new Response(JSON.stringify({
          sessionCode
        }), {
          status: 200,
          headers: {
            'Content-Type': 'application/json',
            ...corsHeaders
          }
        });
      }

      // Route: WebSocket signaling
      if (path.startsWith('/ws/')) {
        const roomCode = path.substring(4); // Remove "/ws/"
        
        // Validate room code (4 digits)
        if (!/^\d{4}$/.test(roomCode)) {
          return new Response('Invalid room code', { 
            status: 400,
            headers: corsHeaders
          });
        }

        // Get Durable Object stub
        const id = env.SIGNALING_ROOMS.idFromName(roomCode);
        const stub = env.SIGNALING_ROOMS.get(id);
        
        // Forward request to Durable Object
        return stub.fetch(request);
      }

      // Serve static assets (Flutter web build)
      try {
        const response = await getAssetFromKV(
          {
            request,
            waitUntil(promise) {
              return ctx.waitUntil(promise);
            },
          },
          {
            ASSET_NAMESPACE: env.__STATIC_CONTENT,
            ASSET_MANIFEST: env.__STATIC_CONTENT_MANIFEST,
          }
        );

        // Add cache headers for immutable assets
        const cacheHeaders = new Headers(response.headers);
        if (path.match(/\.(js|css|woff2?|ttf|png|jpg|svg)$/)) {
          cacheHeaders.set('Cache-Control', 'public, max-age=31536000, immutable');
        } else {
          cacheHeaders.set('Cache-Control', 'public, max-age=3600');
        }

        return new Response(response.body, {
          status: response.status,
          statusText: response.statusText,
          headers: cacheHeaders,
        });
      } catch (e) {
        // If asset not found, serve index.html for client-side routing
        if (e.status === 404 || e.message.includes('Not Found')) {
          try {
            const indexRequest = new Request(
              new URL('/index.html', request.url),
              request
            );
            
            const response = await getAssetFromKV(
              {
                request: indexRequest,
                waitUntil(promise) {
                  return ctx.waitUntil(promise);
                },
              },
              {
                ASSET_NAMESPACE: env.__STATIC_CONTENT,
                ASSET_MANIFEST: env.__STATIC_CONTENT_MANIFEST,
              }
            );

            return new Response(response.body, {
              status: 200,
              headers: {
                'Content-Type': 'text/html',
                'Cache-Control': 'public, max-age=3600',
              },
            });
          } catch (indexError) {
            return new Response('Not Found', { status: 404 });
          }
        }
        
        throw e;
      }
    } catch (error) {
      console.error('Worker error:', error);
      return new Response(JSON.stringify({
        error: error.message || 'Internal server error'
      }), {
        status: 500,
        headers: {
          'Content-Type': 'application/json',
          ...corsHeaders
        }
      });
    }
  }
};
