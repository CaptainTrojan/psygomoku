<template>
  <h1>Connected: {{ connected }}</h1>
</template>

<script>

import {SocketioService} from "@/services/socketio.service";
import {ConnectionCallback} from "@/services/socketio.service";

export default {
  name: "PlayPage",
  data(){
    return {
      connected: false
    }
  },
  mounted() {
    console.log("Setup called.");
    let self = this;
    SocketioService.setupSocketConnection(
      new ConnectionCallback(
        function (){
          self.connected = true;
        },
          function (){
          self.connected = false;
        },
          function (){
          self.connected = false;
        },
      )
    );
  },
  unmounted() {
    console.log("Unmounted called.");
    SocketioService.closeConnection();
  }
}
</script>

<style scoped>

</style>