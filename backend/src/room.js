/**
 * SignalingRoom - Durable Object for WebRTC signaling
 * 
 * Manages a single game session between two peers (host and joiner).
 * Relays SDP offers/answers and ICE candidates between peers via WebSocket.
 */
export class SignalingRoom {
  constructor(state, env) {
    this.state = state;
    this.env = env;
    this.connections = new Map(); // Map<WebSocket, {role: 'host'|'joiner', connectedAt: Date}>
    this.lastActivity = Date.now();
  }

  async fetch(request) {
    // Upgrade to WebSocket
    const upgradeHeader = request.headers.get('Upgrade');
    if (!upgradeHeader || upgradeHeader !== 'websocket') {
      return new Response('Expected WebSocket', { status: 426 });
    }

    // Check if room is full (max 2 connections)
    if (this.connections.size >= 2) {
      return new Response('Room full', { status: 403 });
    }

    // Create WebSocket pair
    const pair = new WebSocketPair();
    const [client, server] = Object.values(pair);

    // Accept the WebSocket connection
    server.accept();

    // Determine role: first connection is host, second is joiner
    const role = this.connections.size === 0 ? 'host' : 'joiner';
    
    this.connections.set(server, {
      role,
      connectedAt: Date.now()
    });

    this.lastActivity = Date.now();

    // Send role confirmation
    server.send(JSON.stringify({
      type: 'ROLE_ASSIGNED',
      role
    }));

    // If this is the second connection, notify the first peer
    if (this.connections.size === 2) {
      await this.notifyPeers({
        type: 'PEER_JOINED',
        role
      }, server);
    }

    // Set up message handler
    server.addEventListener('message', async (event) => {
      try {
        this.lastActivity = Date.now();
        const data = JSON.parse(event.data);
        
        // Forward signaling messages to the peer
        await this.forwardToPeer(server, data);
      } catch (error) {
        console.error('Message handling error:', error);
        server.send(JSON.stringify({
          type: 'ERROR',
          message: error.message
        }));
      }
    });

    // Set up close handler
    server.addEventListener('close', async () => {
      const connInfo = this.connections.get(server);
      this.connections.delete(server);

      // Notify peer that connection was lost
      if (connInfo) {
        await this.notifyPeers({
          type: 'PEER_DISCONNECTED',
          role: connInfo.role
        }, server);
      }

      // Clean up if room is empty
      if (this.connections.size === 0) {
        // Room will be garbage collected automatically
      }
    });

    // Set up error handler
    server.addEventListener('error', (event) => {
      console.error('WebSocket error:', event);
    });

    // Return the client side of the WebSocket pair
    return new Response(null, {
      status: 101,
      webSocket: client
    });
  }

  /**
   * Forward signaling data to the peer
   */
  async forwardToPeer(sender, data) {
    const senderInfo = this.connections.get(sender);
    if (!senderInfo) return;

    // Find the peer (the other connection)
    for (const [ws, info] of this.connections.entries()) {
      if (ws !== sender) {
        try {
          ws.send(JSON.stringify(data));
        } catch (error) {
          console.error('Error forwarding to peer:', error);
        }
      }
    }
  }

  /**
   * Notify all peers except the sender
   */
  async notifyPeers(message, excludeSocket = null) {
    for (const [ws, info] of this.connections.entries()) {
      if (ws !== excludeSocket) {
        try {
          ws.send(JSON.stringify(message));
        } catch (error) {
          console.error('Error notifying peer:', error);
        }
      }
    }
  }

  /**
   * Automatic cleanup for inactive rooms
   * Called periodically by the Durable Objects runtime
   */
  async alarm() {
    const TEN_MINUTES = 10 * 60 * 1000;
    const now = Date.now();

    if (now - this.lastActivity > TEN_MINUTES) {
      // Close all connections and clean up
      for (const [ws] of this.connections.entries()) {
        ws.close(1000, 'Room expired due to inactivity');
      }
      this.connections.clear();
    } else {
      // Schedule next check
      await this.state.storage.setAlarm(now + TEN_MINUTES);
    }
  }
}
