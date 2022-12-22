import { io } from 'socket.io-client';

class SocketioService {
    socket;
    constructor() {

    }

    setupSocketConnection(){
        console.log("Trying to setup socket connection...");

        // @ts-ignore
        this.socket = io(import.meta.env.VITE_SOCKET_ENDPOINT);

        this.socket.on("error", function (){
            console.log("Error :)");
        });

        this.socket.on("connect", function () {
            console.log("CLIENT: Connected!")
        });

        this.socket.on("disconnect", function (){
            console.log("CLIENT: Disconnected.");
        });
    }

    closeConnection() {
        this.socket.disconnect();
        delete this.socket;
    }
}

export default new SocketioService();