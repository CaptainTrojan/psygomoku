<template>
  <h1>Connected: {{ socket.connected }}</h1>
</template>

<script>

import SocketioService from "../services/socketio.service";

export default {
  name: "PlayPage",
  data(){
    return {
      socket: {
        connected: false
      }
    }
  },
  mounted() {
    console.log("Setup called.");
    SocketioService.setupSocketConnection();
    this.socket = SocketioService.socket;
  },
  unmounted() {
    console.log("Unmounted called.");
    SocketioService.closeConnection();
    this.socket = {connected: false}
  }
}
</script>

<style scoped>

</style>