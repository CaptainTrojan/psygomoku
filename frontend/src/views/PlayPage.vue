<template>
  <div id="popup" ref="popup_div" v-show="popup_showing"></div>

  <h1>Connected: {{ connected }}</h1><br/>

  <Lobby @popup="popup" @start-game="toggle_game" v-if="in_lobby"></Lobby>
  <Game @end-game="toggle_game" v-if="!in_lobby"></Game>
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
      popup_showing: false
    }
  },
  methods: {
    toggle_game(){
      this.in_lobby = !this.in_lobby;
    },
    popup(text){
      console.log(this.$refs)
      this.$refs.popup_div.textContent = text;
      this.popup_showing = true;
      setTimeout(() => {
        this.popup_showing = false;
      }, 2000);
    },
  },
  beforeMount() {
    console.log("Mounting play page...");
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
    console.log("Unmounted play page.");
    SocketioService.closeConnection();
  }
}

</script>

<style scoped>
#popup {
  text-align: center;
  width: 100%;
  border: 2px solid #ffc738;
  background-color: #ffc738;
  z-index: 2;
  border-radius: 5px;
  padding: 5px;
  position: absolute;
  top: 0;
  left: 0;
}
</style>