import { io } from 'socket.io-client';

class SocketioService {
    socket;
    constructor() {

    }

    setupSocketConnection(){
        this.socket = io(import.meta.env.VITE_SOCKET_ENDPOINT);
    }
}

export default new SocketioService();