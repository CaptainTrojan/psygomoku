<template>
  <h1>Connected: {{ connected }}</h1>

  <Lobby @clickeded="toggle_game" v-if="in_lobby"></Lobby>
  <Game v-if="!in_lobby"></Game>
</template>

<script>

import {SocketioService} from "@/services/socketio.service";
import {ConnectionCallback} from "@/services/socketio.service";
import Lobby from "@/components/play/Lobby.vue"
import Game from "@/components/play/Game.vue"

export default {
  name: "PlayPage",
  components: {
    Lobby, Game
  },
  data(){
    return {
      in_lobby: true,
      connected: false,
    }
  },
  methods: {
    toggle_game(){
      this.in_lobby = !this.in_lobby;
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